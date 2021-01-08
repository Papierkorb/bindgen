#ifndef ENUM_MATCH_HANDLER_HPP
#define ENUM_MATCH_HANDLER_HPP

class EnumMatchHandler : public clang::ast_matchers::MatchFinder::MatchCallback {
public:
	EnumMatchHandler(Document &doc, const std::string &name);

	virtual void run(const clang::ast_matchers::MatchFinder::MatchResult &Result) override;

	bool runOnEnum(Enum &e, const clang::EnumDecl *enumeration);

	// Support for
	// 1. typedef'd enum types
	// 2. Qts `typedef QFlags<ENUM> ENUMs;` paradigm
	bool runOnTypedef(Enum &e, const clang::TypedefNameDecl *typeDecl);

	bool handleQFlagsType(Enum &e, const clang::ClassTemplateSpecializationDecl *tmpl);

private:
	Document &m_document;
	std::string m_enumName;
};

#endif // ENUM_MATCH_HANDLER_HPP
