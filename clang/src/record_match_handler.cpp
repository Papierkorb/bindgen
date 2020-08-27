#include "common.hpp"
#include "record_match_handler.hpp"
#include "type_helper.hpp"

RecordMatchHandler::RecordMatchHandler(Document &doc, const std::string &name)
	: m_document(doc), m_className(name)
{
}

void RecordMatchHandler::run(const clang::ast_matchers::MatchFinder::MatchResult &result) {
	const clang::CXXRecordDecl *record0 = result.Nodes.getNodeAs<clang::CXXRecordDecl>("recordDecl");
	if (record0) {
		m_classesToRun.push_back(std::make_pair(record0, this->m_className));
	}

	bool anonymous = false;
	while (!m_classesToRun.empty()) {
		const clang::CXXRecordDecl *record = m_classesToRun.back().first;
		std::string name = m_classesToRun.back().second;
		m_classesToRun.pop_back();

		Class klass;
		klass.name = name;
		klass.isAnonymous = anonymous;
		if (runOnRecord(klass, record)) {
			this->m_document.classes[name] = klass;
		}

		// every added record is anonymous except the first one
		anonymous = true;
	}
}

bool RecordMatchHandler::runOnMethod(Method &m, Class &klass, const clang::CXXMethodDecl *method, bool isSignal) {
	if (method->isDeleted())
		return false;

	m.className = method->getParent()->getQualifiedNameAsString();
	m.isConst = method->isConst();
	m.isVirtual = method->isVirtual();
	m.isPure = method->isPure();
	m.isExternC = method->isExternC();
	m.access = method->getAccess();

	clang::ASTContext &ctx = method->getASTContext();
	const clang::CXXConstructorDecl* ctor = llvm::dyn_cast<clang::CXXConstructorDecl>(method);

	// Figure out what we have found
	if (ctor) {
		if (ctor->isMoveConstructor()) {
			return false; // Move constructors aren't really wrappable
		}

		m.type = ctor->isCopyConstructor() ? Method::CopyConstructor : Method::Constructor;
	} else if (llvm::isa<clang::CXXDestructorDecl>(method)) {
		klass.isDestructible = m.access != clang::AS_private;

		// For a destructor, only store if this type can be destructed publicly or not.
		return false;

	} else { // Normal method
		m.type = method->isStatic() ? Method::StaticMethod : Method::MemberMethod;
		m.name = method->getNameAsString();
		m.returnType = TypeHelper::qualTypeToType(method->getReturnType(), ctx);

		if (method->getOverloadedOperator() != clang::OO_None) {
			m.type = Method::Operator;
		} else if (auto conv = llvm::dyn_cast<clang::CXXConversionDecl>(method)) {
			m.type = Method::Operator; // TODO: Add conversion method support.

		} else if (isSignal && m.type == Method::MemberMethod && method->isUserProvided()) {
			m.type = Method::Signal;
		}
	}

	TypeHelper::addFunctionParameters(method, m);
	return true;
}

bool RecordMatchHandler::runOnRecord(Class &klass, const clang::CXXRecordDecl *record) {
	const auto *typeInfoResult = m_document.findTypeInfoResult(klass.name);

	klass.hasDefaultConstructor = record->hasDefaultConstructor() &&
		!(typeInfoResult && !typeInfoResult->isDefaultConstructible);
	klass.hasCopyConstructor = record->hasCopyConstructorWithConstParam();
	klass.isAbstract = record->isAbstract();
	klass.isClass = record->isClass();
	klass.isUnion = record->isUnion();

	clang::TypeInfo typeInfo = record->getASTContext().getTypeInfo(record->getTypeForDecl());
	uint64_t bitSize = typeInfo.Width;
	if (typeInfo.AlignIsRequired) bitSize += typeInfo.Align;
	klass.byteSize = bitSize / 8;

	for (clang::CXXBaseSpecifier base : record->bases()) {
		klass.bases.push_back(handleBaseClass(base));
	}

	bool isPublic = record->isStruct(); // Default public for structs!
	bool isSignal = false; // Qt signal support
	int unnamedCount = 0;

	for (clang::Decl *decl : record->decls()) {
		if (clang::CXXMethodDecl *method = llvm::dyn_cast<clang::CXXMethodDecl>(decl)) {
			Method m;
			if (runOnMethod(m, klass, method, isSignal)) {
				klass.methods.push_back(m);
			}
		} else if (clang::AccessSpecDecl *spec = llvm::dyn_cast<clang::AccessSpecDecl>(decl)) {
			isSignal = checkAccessSpecForSignal(spec);
		} else if (clang::FieldDecl *field = llvm::dyn_cast<clang::FieldDecl>(decl)) {
			Field f;
			if (runOnField(f, klass, field)) {
				klass.fields.push_back(f);
			}
		} else if (clang::CXXRecordDecl *tag = llvm::dyn_cast<clang::CXXRecordDecl>(decl)) {
			if (!tag->getIdentifier()) {
				std::string ident = "Unnamed" + std::to_string(unnamedCount++);
				tag->setDeclName(&tag->getASTContext().Idents.get(ident));
				m_classesToRun.push_back(std::make_pair(tag, klass.name + "::" + ident));
			}
		}
	}

	return true;
}

bool RecordMatchHandler::runOnField(Field &f, Class &klass, const clang::FieldDecl *field) {
	f.name = field->getNameAsString();
	f.access = field->getAccess();
	// f.bitField = TODO

	TypeHelper::qualTypeToType(f, field->getType(), field->getASTContext());
	return true;
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
	b.name = base.getType()->getAsCXXRecordDecl()->getQualifiedNameAsString();

	return b;
}
