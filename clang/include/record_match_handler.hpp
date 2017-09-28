#ifndef RECORD_MATCH_HANDLER_HPP
#define RECORD_MATCH_HANDLER_HPP

class RecordMatchHandler : public clang::ast_matchers::MatchFinder::MatchCallback {
public:
	RecordMatchHandler(const std::string &name);

	Class klass() const;

	Type qualTypeToType(const clang::QualType &qt, clang::ASTContext &ctx);

	void qualTypeToType(Type &target, const clang::QualType &qt, clang::ASTContext &ctx);

	CopyPtr<Template> handleTemplate(const clang::ClassTemplateSpecializationDecl *decl);

	virtual void run(const clang::ast_matchers::MatchFinder::MatchResult &Result) override;

	void runOnMethod(const clang::CXXMethodDecl *method, bool isSignal);

	Argument processFunctionParameter(const clang::ParmVarDecl *decl);

	bool describesStringClass(const clang::CXXConstructorDecl *ctorDecl);

	bool stringLiteralFromExpression(Argument &arg, const clang::Expr *expr);

	bool tryReadStringConstructor(Argument &arg, const clang::CXXConstructExpr *expr);

	void tryReadDefaultArgumentValue(Argument &arg, const clang::QualType &qt, clang::ASTContext &ctx, const clang::Expr *expr);

	void runOnRecord(const clang::CXXRecordDecl *record);

	void runOnField(const clang::FieldDecl *field);

	bool checkAccessSpecForSignal(clang::AccessSpecDecl *spec);

	std::string getSourceFromRange(clang::SourceRange range, clang::SourceManager &sourceMgr);

	BaseClass handleBaseClass(const clang::CXXBaseSpecifier &base);
private:
	Class m_class;
};

#endif // RECORD_MATCH_HANDLER_HPP
