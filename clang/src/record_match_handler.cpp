#include "common.hpp"
#include "record_match_handler.hpp"

RecordMatchHandler::RecordMatchHandler(const std::string &name) {
	this->m_class.name = name;
}

Class RecordMatchHandler::klass() const {
  return this->m_class;
}

Type RecordMatchHandler::qualTypeToType(const clang::QualType &qt, clang::ASTContext &ctx) {
	Type type;
	qualTypeToType(type, qt, ctx);
	return type;
}

void RecordMatchHandler::qualTypeToType(Type &target, const clang::QualType &qt, clang::ASTContext &ctx) {
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
		if (const auto *tmpl = llvm::dyn_cast<clang::ClassTemplateSpecializationDecl>(record)) {
			target.templ = handleTemplate(record, tmpl);
		}
	}

	// Not a reference or pointer.
	target.isConst = qt.isConstQualified();
	target.isVoid = qt->isVoidType();
	target.isBuiltin = qt->isBuiltinType();
	target.baseName = clang::TypeName::getFullyQualifiedName(qt.getUnqualifiedType(), ctx);
}

CopyPtr<Template> RecordMatchHandler::handleTemplate(const clang::CXXRecordDecl *record, const clang::ClassTemplateSpecializationDecl *decl) {
	Template t;
	clang::ASTContext &ctx = decl->getASTContext();

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

void RecordMatchHandler::run(const clang::ast_matchers::MatchFinder::MatchResult &Result) {
	const clang::CXXRecordDecl *record = Result.Nodes.getNodeAs<clang::CXXRecordDecl>("recordDecl");
	if (record) runOnRecord(record);
}

void RecordMatchHandler::runOnMethod(const clang::CXXMethodDecl *method, bool isSignal) {
	Method m;
	m.className = method->getParent()->getQualifiedNameAsString();
	m.isConst = method->isConst();
	m.isVirtual = method->isVirtual();
	m.isPure = method->isPure();
	m.access = method->getAccess();

	clang::ASTContext &ctx = method->getASTContext();
	const clang::CXXConstructorDecl* ctor = llvm::dyn_cast<clang::CXXConstructorDecl>(method);

	// Figure out what we have found
	if (ctor) {
		if (ctor->isMoveConstructor()) {
			return; // Move constructors aren't really wrappable
		}

		m.type = ctor->isCopyConstructor() ? Method::CopyConstructor : Method::Constructor;
	} else if (llvm::isa<clang::CXXDestructorDecl>(method)) {
		this->m_class.isDestructible = m.access != clang::AS_private;

		// For a destructor, only store if this type can be destructed publicly or
		// not.
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

Argument RecordMatchHandler::processFunctionParameter(const clang::ParmVarDecl *decl) {
	clang::ASTContext &ctx = decl->getASTContext();
	Argument arg;

	clang::QualType qt = decl->getType();
	qualTypeToType(arg, qt, ctx);
	arg.name = decl->getQualifiedNameAsString();
	arg.hasDefault = decl->hasDefaultArg();
	arg.value = JsonStream::Null;

	// If the parameter has a default value, try to figure out this value.  Can
	// fail if e.g. the call has side-effects (Like calling another method).  Will
	// work for constant expressions though, like `true` or `3 + 5`.
	if (arg.hasDefault) {
		tryReadDefaultArgumentValue(arg, qt, ctx, decl->getDefaultArg());
	}

	return arg;
}

bool RecordMatchHandler::describesStringClass(const clang::CXXConstructorDecl *ctorDecl) {
	std::string name = ctorDecl->getParent()->getQualifiedNameAsString();
	if (name == "std::__cxx11::basic_string" || name == "QString") {
		return true;
	} else {
		return false;
	}
}

bool RecordMatchHandler::stringLiteralFromExpression(Argument &arg, const clang::Expr *expr) {
	if (const clang::MaterializeTemporaryExpr *argExpr = llvm::dyn_cast<clang::MaterializeTemporaryExpr>(expr)) {
		return stringLiteralFromExpression(arg, argExpr->GetTemporaryExpr());
	} else if (const clang::CXXBindTemporaryExpr *bindExpr = llvm::dyn_cast<clang::CXXBindTemporaryExpr>(expr)) {
		return stringLiteralFromExpression(arg, bindExpr->getSubExpr());
	} else if (const clang::CastExpr *castExpr = llvm::dyn_cast<clang::CastExpr>(expr)) {
		return stringLiteralFromExpression(arg, castExpr->getSubExprAsWritten());
	} else if (const clang::CXXConstructExpr *ctorExpr = llvm::dyn_cast<clang::CXXConstructExpr>(expr)) {
		return tryReadStringConstructor(arg, ctorExpr);
	} else if (const clang::StringLiteral *strExpr = llvm::dyn_cast<clang::StringLiteral>(expr)) {
		// We found it!
		arg.value = strExpr->getString().str();
		return true;
	} else { // Failed to destructure.
		return false;
	}
}

bool RecordMatchHandler::tryReadStringConstructor(Argument &arg, const clang::CXXConstructExpr *expr) {
	if (!describesStringClass(expr->getConstructor())) {
		return false;
	}

	// The constructor call needs to have no (= empty) or a single argument.
	if (expr->getNumArgs() == 0) { // This is an empty string!
		arg.value = std::string();
		return true;
	} else if (expr->getNumArgs() == 1) {
		return stringLiteralFromExpression(arg, expr->getArg(0));
	} else { // No rules for more than one argument.
		return false;
	}
}

void RecordMatchHandler::tryReadDefaultArgumentValue(Argument &arg, const clang::QualType &qt,
  clang::ASTContext &ctx, const clang::Expr *expr) {
	clang::Expr::EvalResult result;

	if (!expr->EvaluateAsRValue(result, ctx)) {
		// Failed to evaluate - Try to unpack this expression
		stringLiteralFromExpression(arg, expr);
		return;
	}

	if (result.HasSideEffects || result.HasUndefinedBehavior) {
		return; // Don't accept if there are side-effects or undefined behaviour.
	}

	if (qt->isPointerType()) {
		// For a pointer-type, just store if it was `nullptr` (== true).
		arg.value = result.Val.isNullPointer();
	} else if (qt->isBooleanType()) {
		arg.value = result.Val.getInt().getBoolValue();
	} else if (qt->isIntegerType()) {
		const llvm::APSInt &v = result.Val.getInt();
		int64_t i64 = v.getExtValue();

		if (qt->isSignedIntegerType())
			arg.value = i64;
		else // Is there better way?
			arg.value = static_cast<uint64_t>(i64);
	} else if (qt->isFloatingType()) {
		arg.value = result.Val.getFloat().convertToDouble();
	}
}

void RecordMatchHandler::runOnRecord(const clang::CXXRecordDecl *record) {
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

void RecordMatchHandler::runOnField(const clang::FieldDecl *field) {
	Field f;
	f.name = field->getNameAsString();
	f.access = field->getAccess();
	// f.bitField = TODO

	qualTypeToType(f, field->getType(), field->getASTContext());
	this->m_class.fields.push_back(f);
}

bool RecordMatchHandler::checkAccessSpecForSignal(clang::AccessSpecDecl *spec) {
	clang::SourceRange range = spec->getSourceRange();
	clang::SourceManager &sourceMgr = spec->getASTContext().getSourceManager();
	std::string snippet = getSourceFromRange(range, sourceMgr);

	return (snippet == "signals" || snippet == "Q_SIGNALS");
}

std::string RecordMatchHandler::getSourceFromRange(clang::SourceRange range, clang::SourceManager &sourceMgr) {
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

BaseClass RecordMatchHandler::handleBaseClass(const clang::CXXBaseSpecifier &base) {
	BaseClass b;

	b.isVirtual = base.isVirtual();
	b.inheritedConstructor = base.getInheritConstructors();
	b.access = base.getAccessSpecifier();
	b.name = base.getType()->getAsCXXRecordDecl()->getNameAsString();

	return b;
}
