#ifndef RECORD_MATCH_HANDLER_HPP
#define RECORD_MATCH_HANDLER_HPP

class RecordMatchHandler : public clang::ast_matchers::MatchFinder::MatchCallback {
public:
	RecordMatchHandler(Document &doc, const std::string &name);

	virtual void run(const clang::ast_matchers::MatchFinder::MatchResult &Result) override;

private:
	bool runOnMethod(Method &m, Class &klass, const clang::CXXMethodDecl *method, bool isSignal);

	bool runOnRecord(Class &klass, const clang::CXXRecordDecl *record);

	bool runOnField(Field &f, Class &klass, const clang::FieldDecl *field);

	bool checkAccessSpecForSignal(clang::AccessSpecDecl *spec);

	std::string getSourceFromRange(clang::SourceRange range, clang::SourceManager &sourceMgr);

	BaseClass handleBaseClass(const clang::CXXBaseSpecifier &base);

private:
	Document &m_document;
	std::string m_className;

	// first = record definition, second = qualified type name
	std::vector<std::pair<const clang::CXXRecordDecl *, std::string>> m_classesToRun;
};

#endif // RECORD_MATCH_HANDLER_HPP
