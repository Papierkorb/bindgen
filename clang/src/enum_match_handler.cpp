#include "common.hpp"
#include "enum_match_handler.hpp"

EnumMatchHandler::EnumMatchHandler(Document &doc, const std::string &name)
	: m_document(doc), m_enumName(name)
{
}

void EnumMatchHandler::run(const clang::ast_matchers::MatchFinder::MatchResult &Result) {
	const clang::EnumDecl *enumeration = Result.Nodes.getNodeAs<clang::EnumDecl>("enumDecl");
	const clang::TypedefNameDecl *typeDecl = Result.Nodes.getNodeAs<clang::TypedefNameDecl>("typedefNameDecl");

	Enum e;
	if (enumeration && runOnEnum(e, enumeration)) {
		this->m_document.enums[e.name] = e;
	}
	else if (typeDecl && runOnTypedef(e, typeDecl)) {
		this->m_document.enums[e.name] = e;
	}
}

bool EnumMatchHandler::runOnEnum(Enum &e, const clang::EnumDecl *enumeration) {
	e.name = this->m_enumName;
	e.type = enumeration->getIntegerType().getUnqualifiedType().getAsString();

	for (const clang::EnumConstantDecl *field : enumeration->enumerators()) {
		std::string name = field->getNameAsString();
		int64_t value = field->getInitVal().getExtValue();
		e.values[name] = value;
	}

	return true;
}

bool EnumMatchHandler::runOnTypedef(Enum &e, const clang::TypedefNameDecl *typeDecl) {
	clang::QualType qt = typeDecl->getUnderlyingType();

	// Support typedef'd enum types.
	if (const clang::EnumType *eType = qt->getAs<clang::EnumType>()) {
		return runOnEnum(e, eType->getDecl());
	} else if (auto tmpl = llvm::dyn_cast<clang::ClassTemplateSpecializationDecl>(qt->getAsCXXRecordDecl())) {
		std::string templateName = tmpl->getTemplateInstantiationPattern()->getNameAsString();

		// Check if we have a `QFlags` template type
		if (templateName == "QFlags") {
			return handleQFlagsType(e, tmpl);
		}
	}

	return false;
}

bool EnumMatchHandler::handleQFlagsType(Enum &e, const clang::ClassTemplateSpecializationDecl *tmpl) {
	if (tmpl->getTemplateInstantiationArgs().size() != 1)
		return false; // Size is expected to be "1"!

	// Grab the template argument, check if it's an `enum`, and if so, process it!
	const clang::TemplateArgument &arg = tmpl->getTemplateInstantiationArgs().get(0);
	clang::QualType qt = arg.getAsType();

	if (!qt->isEnumeralType())
		return false;

	e.isFlags = true;
	const clang::EnumType *enumType = qt->getAs<clang::EnumType>();
	return runOnEnum(e, llvm::dyn_cast<clang::EnumDecl>(enumType->getDecl()));
}
