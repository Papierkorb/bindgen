#include "common.hpp"
#include "enum_match_handler.hpp"

EnumMatchHandler::EnumMatchHandler(const std::string &name) {
	this->m_enum.name = name;
}

Enum EnumMatchHandler::enumeration() const {
	return this->m_enum;
}

void EnumMatchHandler::run(const clang::ast_matchers::MatchFinder::MatchResult &Result) {
	const clang::EnumDecl *enumeration = Result.Nodes.getNodeAs<clang::EnumDecl>("enumDecl");
	const clang::TypedefNameDecl *typeDecl = Result.Nodes.getNodeAs<clang::TypedefNameDecl>("typedefNameDecl");

	if (enumeration) runOnEnum(enumeration);
	if (typeDecl) runOnTypedef(typeDecl);
}

void EnumMatchHandler::runOnEnum(const clang::EnumDecl *enumeration) {
	this->m_enum.type = enumeration->getIntegerType().getUnqualifiedType().getAsString();

	for (const clang::EnumConstantDecl *field : enumeration->enumerators()) {
		std::string name = field->getNameAsString();
		int64_t value = field->getInitVal().getExtValue();
		this->m_enum.values.push_back(std::make_pair(name, value));
	}
}

void EnumMatchHandler::runOnTypedef(const clang::TypedefNameDecl *typeDecl) {
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

void EnumMatchHandler::handleQFlagsType(const clang::ClassTemplateSpecializationDecl *tmpl) {
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
