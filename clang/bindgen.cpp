#include "clang/Tooling/CommonOptionsParser.h"
#include "clang/Tooling/Core/QualTypeNames.h"
#include "clang/ASTMatchers/ASTMatchFinder.h"
#include "clang/Frontend/CompilerInstance.h"
#include "clang/Frontend/FrontendActions.h"
#include "clang/ASTMatchers/ASTMatchers.h"
#include "clang/AST/ASTConsumer.h"
#include "clang/Tooling/Tooling.h"
#include "clang/AST/ASTContext.h"
#include "clang/Driver/Options.h"
#include "clang/AST/APValue.h"
#include "clang/AST/AST.h"
#include <iostream>
#include <sstream>
#include <utility>
#include <vector>
#include <map>

#include "helper.hpp"
#include "json_stream.hpp"
#include "structures.hpp"

static llvm::cl::OptionCategory BindgenCategory("bindgen options");
static std::unique_ptr<llvm::opt::OptTable> Options(clang::driver::createDriverOptTable());
static llvm::cl::list<std::string> ClassList("c", llvm::cl::desc("Classes to inspect"), llvm::cl::value_desc("class"));
static llvm::cl::list<std::string> EnumList("e", llvm::cl::desc("Enums to inspect"), llvm::cl::value_desc("enum"));

class RecordMatchHandler : public clang::ast_matchers::MatchFinder::MatchCallback {
public:
	RecordMatchHandler(const std::string &name) {
		this->m_class.name = name;
	}

	Class klass() const
	{ return this->m_class; }

	Type qualTypeToType(const clang::QualType &qt, clang::ASTContext &ctx) {
		Type type;
		qualTypeToType(type, qt, ctx);
		return type;
	}

	void qualTypeToType(Type &target, const clang::QualType& qt, clang::ASTContext &ctx) {
		if (target.fullName.empty()) {
			target.fullName = clang::TypeName::getFullyQualifiedName(qt, ctx);
		}

		if (qt->isReferenceType() || qt->isPointerType()) {
			target.isReference = target.isReference || qt->isReferenceType();
			target.isMove = target.isMove || qt->isRValueReferenceType();
			target.pointer++;
			return qualTypeToType(target, qt->getPointeeType(), ctx); // Recurse
		}

		if (const auto *record = qt->getAsCXXRecordDecl()) {
			if (const auto *tmpl = llvm::dyn_cast<clang::ClassTemplateSpecializationDecl>(qt->getAsCXXRecordDecl())) {
			target.templ = handleTemplate(tmpl);
			}
		}

		// Not a reference or pointer.
		target.isConst = qt.isConstQualified();
		target.isVoid = qt->isVoidType();
		target.isBuiltin = qt->isBuiltinType();
		target.baseName = clang::TypeName::getFullyQualifiedName(qt.getUnqualifiedType(), ctx);
	}

	CopyPtr<Template> handleTemplate(const clang::ClassTemplateSpecializationDecl *decl) {
		Template t;
		clang::ASTContext &ctx = decl->getASTContext();
		const clang::CXXRecordDecl *record = decl->getTemplateInstantiationPattern();

		if (!record) return CopyPtr<Template>();

		const clang::Type *typePtr = record->getTypeForDecl();
		clang::QualType qt(typePtr, 0);
		t.baseName = record->getQualifiedNameAsString();
		t.fullName = clang::TypeName::getFullyQualifiedName(qt, ctx);

		for (const clang::TemplateArgument &argument : decl->getTemplateInstantiationArgs().asArray()) {

			// Sanity check, ignore whole template otherwise.
			if (argument.getKind() != clang::TemplateArgument::Type)
				return CopyPtr<Template>();

			Type type = qualTypeToType(argument.getAsType(), ctx);
			t.arguments.push_back(type);
		}

		return CopyPtr<Template>(t);
	}

	virtual void run(const clang::ast_matchers::MatchFinder::MatchResult &Result) override {
		const clang::CXXRecordDecl *record = Result.Nodes.getNodeAs<clang::CXXRecordDecl>("recordDecl");
		if (record) runOnRecord(record);
	}

	void runOnMethod(const clang::CXXMethodDecl *method, bool isSignal) {
		Method m;
		m.className = method->getParent()->getQualifiedNameAsString();
		m.isConst = method->isConst();
		m.isVirtual = method->isVirtual();
		m.isPure = method->isPure();
		m.access = method->getAccess();

		if (m.access != clang::AS_public && m.access != clang::AS_protected)
			return;

		clang::ASTContext &ctx = method->getASTContext();

		const clang::CXXConstructorDecl* ctor = llvm::dyn_cast<clang::CXXConstructorDecl>(method);

		// Figure out what we have found
		if (ctor) {
			if (ctor->isMoveConstructor()) {
				return; // Move constructors aren't really wrappable
			}

			m.type = ctor->isCopyConstructor() ? Method::CopyConstructor : Method::Constructor;
		} else if (llvm::isa<clang::CXXDestructorDecl>(method)) {
			// Everything can be destroyed.  Don't expose explicitly.
			return;

		} else { // Normal method
			m.type = method->isStatic() ? Method::StaticMethod : Method::MemberMethod;
			m.name = method->getNameAsString();
			m.returnType = qualTypeToType(method->getReturnType(), ctx);

			if (method->getOverloadedOperator() != clang::OO_None) {
				m.type = Method::Operator;
			} else if (auto conv = llvm::dyn_cast<clang::CXXConversionDecl>(method)) {
				m.type = Method::Operator; // TODO: Add conversion method support.

			} else if (isSignal && m.type == Method::MemberMethod && method->isUserProvided()) {
				m.type = Method::Signal;
			}
		}

		for (int i = 0; i < method->getNumParams(); i++) {
			Argument arg = processFunctionParameter(method->parameters()[i]);

			if (arg.hasDefault && m.firstDefaultArgument < 0)
				m.firstDefaultArgument = i;

			m.arguments.push_back(arg);
		}

		// And we're done with this method!
		this->m_class.methods.push_back(m);
	}

	Argument processFunctionParameter(const clang::ParmVarDecl *decl) {
		clang::ASTContext &ctx = decl->getASTContext();
		Argument arg;

		clang::QualType qt = decl->getType();
		qualTypeToType(arg, qt, ctx);
		arg.name = decl->getQualifiedNameAsString();
		arg.hasDefault = decl->hasDefaultArg();
		arg.kind = Argument::TerminalKind;
		arg.terminal_value = JsonStream::Null;

		// If the parameter has a default value, try to figure out this value.  Can
		// fail if e.g. the call has side-effects (Like calling another method).  Will
		// work for constant expressions though, like `true` or `3 + 5`.
		if (arg.hasDefault) {
			tryReadDefaultArgumentValue(arg, qt, ctx, decl->getDefaultArg());
		}

		return arg;
	}

	void tryReadDefaultArgumentValue(Argument &arg, const clang::QualType &qt, clang::ASTContext &ctx, const clang::Expr *expr) {
		clang::Expr::EvalResult result;

		if (!expr->EvaluateAsRValue(result, ctx)) {
			return; // Failed to evaluate.
		}

		if (result.HasSideEffects || result.HasUndefinedBehavior) {
			return; // Don't accept if there are side-effects or undefined behaviour.
		}

		if (qt->isPointerType()) {
			// For a pointer-type, just store if it was `nullptr` (== true).
			arg.kind = Argument::BoolKind;
			arg.bool_value = result.Val.isNullPointer();
		} else if (qt->isBooleanType()) {
			arg.kind = Argument::BoolKind;
			arg.bool_value = result.Val.getInt().getBoolValue();
		} else if (qt->isIntegerType()) {
			const llvm::APSInt &v = result.Val.getInt();
			int64_t i64 = v.getExtValue();

			arg.kind = qt->isSignedIntegerType() ? Argument::IntKind : Argument::UIntKind;
			if (qt->isSignedIntegerType())
				arg.int_value = i64;
			else // Is there better way?
				arg.uint_value = static_cast<uint64_t>(i64);
		} else if (qt->isFloatingType()) {
			arg.kind = Argument::DoubleKind;
			arg.double_value = result.Val.getFloat().convertToDouble();
		}
	}

	void runOnRecord(const clang::CXXRecordDecl *record) {
		this->m_class.hasDefaultConstructor = record->hasDefaultConstructor();
		this->m_class.hasCopyConstructor = record->hasCopyConstructorWithConstParam();
		this->m_class.isAbstract = record->isAbstract();
		this->m_class.isClass = record->isClass();

		clang::TypeInfo typeInfo = record->getASTContext().getTypeInfo(record->getTypeForDecl());
		uint64_t bitSize = typeInfo.Width;
		if (typeInfo.AlignIsRequired) bitSize += typeInfo.Align;
		this->m_class.byteSize = bitSize / 8;

		for (clang::CXXBaseSpecifier base : record->bases()) {
			this->m_class.bases.push_back(handleBaseClass(base));
		}

		bool isPublic = record->isStruct(); // Default public for structs!
		bool isSignal = false; // Qt signal support
		for (clang::Decl *decl : record->decls()) {
			if (clang::CXXMethodDecl *method = llvm::dyn_cast<clang::CXXMethodDecl>(decl)) {
				runOnMethod(method, isSignal);
			} else if (clang::AccessSpecDecl *spec = llvm::dyn_cast<clang::AccessSpecDecl>(decl)) {
				isSignal = checkAccessSpecForSignal(spec);
			} else if (clang::FieldDecl *field = llvm::dyn_cast<clang::FieldDecl>(decl)) {
				runOnField(field);
			} else {
				// std::cerr << this->m_class.name << ": Found " << decl->getDeclKindName() << "\n";
			}
		}
	}

	void runOnField(const clang::FieldDecl *field) {
		Field f;
		f.name = field->getNameAsString();
		f.access = field->getAccess();
		// f.bitField = TODO

		qualTypeToType(f, field->getType(), field->getASTContext());
		this->m_class.fields.push_back(f);
	}

	bool checkAccessSpecForSignal(clang::AccessSpecDecl *spec) {
		clang::SourceRange range = spec->getSourceRange();
		clang::SourceManager &sourceMgr = spec->getASTContext().getSourceManager();
		std::string snippet = getSourceFromRange(range, sourceMgr);

		return (snippet == "signals" || snippet == "Q_SIGNALS");
	}

	std::string getSourceFromRange(clang::SourceRange range, clang::SourceManager &sourceMgr) {
		std::pair<clang::FileID, unsigned> begin = sourceMgr.getDecomposedExpansionLoc(range.getBegin());
		std::pair<clang::FileID, unsigned> end = sourceMgr.getDecomposedExpansionLoc(range.getEnd());

		if (begin.first != end.first)
			return std::string();

		bool invalid = false;
		llvm::StringRef fileBuffer = sourceMgr.getBufferData(begin.first, &invalid);

		if (invalid)
			return std::string();

		unsigned int length = end.second - begin.second;
		return fileBuffer.substr(begin.second, length).str();
	}

	BaseClass handleBaseClass(const clang::CXXBaseSpecifier &base) {
		BaseClass b;

		b.isVirtual = base.isVirtual();
		b.inheritedConstructor = base.getInheritConstructors();
		b.access = base.getAccessSpecifier();
		b.name = base.getType()->getAsCXXRecordDecl()->getNameAsString();

		return b;
	}
private:
	Class m_class;
};

class EnumMatchHandler : public clang::ast_matchers::MatchFinder::MatchCallback {
public:
	EnumMatchHandler(const std::string &name) {
		this->m_enum.name = name;
	}

	Enum enumeration() const
	{ return this->m_enum; }

	virtual void run(const clang::ast_matchers::MatchFinder::MatchResult &Result) override {
		const clang::EnumDecl *enumeration = Result.Nodes.getNodeAs<clang::EnumDecl>("enumDecl");
		const clang::TypedefNameDecl *typeDecl = Result.Nodes.getNodeAs<clang::TypedefNameDecl>("typedefNameDecl");

		if (enumeration) runOnEnum(enumeration);
		if (typeDecl) runOnTypedef(typeDecl);
	}

	void runOnEnum(const clang::EnumDecl *enumeration) {
		this->m_enum.type = enumeration->getIntegerType().getUnqualifiedType().getAsString();

		for (const clang::EnumConstantDecl *field : enumeration->enumerators()) {
			std::string name = field->getNameAsString();
			int64_t value = field->getInitVal().getExtValue();
			this->m_enum.values.push_back(std::make_pair(name, value));
		}
	}

	// Support for
	// 1. typedef'd enum types
	// 2. Qts `typedef QFlags<ENUM> ENUMs;` paradigm
	void runOnTypedef(const clang::TypedefNameDecl *typeDecl) {
		clang::QualType qt = typeDecl->getUnderlyingType();

		// Support typedef'd enum types.
		if (const clang::EnumType *eType = qt->getAs<clang::EnumType>()) {
			runOnEnum(eType->getDecl());
		} else if (auto tmpl = llvm::dyn_cast<clang::ClassTemplateSpecializationDecl>(qt->getAsCXXRecordDecl())) {
			std::string templateName = tmpl->getTemplateInstantiationPattern()->getNameAsString();

			// Check if we have a `QFlags` template type
			if (templateName == "QFlags") {
				handleQFlagsType(tmpl);
			}
		}
	}

	void handleQFlagsType(const clang::ClassTemplateSpecializationDecl *tmpl) {
		if (tmpl->getTemplateInstantiationArgs().size() != 1)
			return; // Size is expected to be "1"!

		// Grab the template argument, check if it's an `enum`, and if so, process it!
		const clang::TemplateArgument &arg = tmpl->getTemplateInstantiationArgs().get(0);
		clang::QualType qt = arg.getAsType();

		if (!qt->isEnumeralType())
			return;

		this->m_enum.isFlags = true;
		const clang::EnumType *enumType = qt->getAs<clang::EnumType>();
		runOnEnum(llvm::dyn_cast<clang::EnumDecl>(enumType->getDecl()));
	}

private:
	Enum m_enum;
};

class BindgenASTConsumer : public clang::ASTConsumer {
public:
	BindgenASTConsumer() {
		using namespace clang::ast_matchers;

		for (const std::string &className : ClassList) {
			DeclarationMatcher classMatcher = cxxRecordDecl(isDefinition(), hasName(className)).bind("recordDecl");

			RecordMatchHandler *handler = new RecordMatchHandler(className);
			this->m_matchFinder.addMatcher(classMatcher, handler);
			this->m_classHandlers.push_back(handler);
		}

		for (const std::string &enumName : EnumList) {
			DeclarationMatcher enumMatcher = enumDecl(hasName(enumName)).bind("enumDecl");
			DeclarationMatcher typedefMatcher = typedefNameDecl(hasName(enumName)).bind("typedefNameDecl");

			EnumMatchHandler *handler = new EnumMatchHandler(enumName);
			this->m_matchFinder.addMatcher(enumMatcher, handler);
			this->m_matchFinder.addMatcher(typedefMatcher, handler);
			this->m_enumHandlers.push_back(handler);
		}
	}

	~BindgenASTConsumer() override {
		for (RecordMatchHandler *handler : this->m_classHandlers) {
			delete handler;
		}
	}

	void HandleTranslationUnit(clang::ASTContext &ctx) override {
		this->m_matchFinder.matchAST(ctx);

		JsonStream stream(std::cout);
		stream << JsonStream::ObjectBegin;
		stream << "enums" << JsonStream::Separator;
		serializeEnumerations(stream);
		stream << JsonStream::Comma;
		stream << "classes" << JsonStream::Separator;
		serializeClasses(stream);
		stream << JsonStream::ObjectEnd;
	}

private:
	void serializeEnumerations(JsonStream &stream) {
		stream << JsonStream::ObjectBegin;

		bool first = true;
		for (EnumMatchHandler *handler : this->m_enumHandlers) {
			Enum enumeration = handler->enumeration();

			if (!first) stream << JsonStream::Comma;
			stream << std::make_pair(enumeration.name, enumeration);

			first = false;
		}

		stream << JsonStream::ObjectEnd;
	}

	void serializeClasses(JsonStream &stream) {
		stream << JsonStream::ObjectBegin;

		bool first = true;
		for (RecordMatchHandler *handler : this->m_classHandlers) {
			Class klass = handler->klass();

			if (!first) stream << JsonStream::Comma;
			stream << std::make_pair(klass.name, klass);

			first = false;
		}

		stream << JsonStream::ObjectEnd;
	}

	std::vector<RecordMatchHandler *> m_classHandlers;
	std::vector<EnumMatchHandler *> m_enumHandlers;
	clang::ast_matchers::MatchFinder m_matchFinder;
};

class BindgenFrontendAction : public clang::ASTFrontendAction {
public:
	void EndSourceFileAction() override {
	}

	std::unique_ptr<clang::ASTConsumer> CreateASTConsumer(clang::CompilerInstance &ci, llvm::StringRef file) override {
		return llvm::make_unique<BindgenASTConsumer>();
	}
};

int main(int argc, const char **argv) {
	clang::tooling::CommonOptionsParser op(argc, argv, BindgenCategory);
	clang::tooling::ClangTool tool(op.getCompilations(), op.getSourcePathList());
	return tool.run(clang::tooling::newFrontendActionFactory<BindgenFrontendAction>().get());
}
