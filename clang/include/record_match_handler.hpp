#ifndef RECORD_MATCH_HANDLER_HPP
#define RECORD_MATCH_HANDLER_HPP

class RecordMatchHandler : public clang::ast_matchers::MatchFinder::MatchCallback {
public:
	RecordMatchHandler(const std::string &name);

	Class klass() const;

	virtual void run(const clang::ast_matchers::MatchFinder::MatchResult &Result) override;

	void runOnMethod(const clang::CXXMethodDecl *method, bool isSignal);

	void runOnRecord(const clang::CXXRecordDecl *record);

	void runOnField(const clang::FieldDecl *field);

	bool checkAccessSpecForSignal(clang::AccessSpecDecl *spec);

	std::string getSourceFromRange(clang::SourceRange range, clang::SourceManager &sourceMgr);

	BaseClass handleBaseClass(const clang::CXXBaseSpecifier &base);
private:
	Class m_class;
};

#endif // RECORD_MATCH_HANDLER_HPP
