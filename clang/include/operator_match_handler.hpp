#ifndef OPERATOR_MATCH_HANDLER_HPP
#define OPERATOR_MATCH_HANDLER_HPP

class OperatorMatchHandler : public clang::ast_matchers::MatchFinder::MatchCallback {
public:
	OperatorMatchHandler(Document &doc, const std::string &name);

	virtual void run(const clang::ast_matchers::MatchFinder::MatchResult &Result) override;

private:
	bool runOnOperator(Method &m, const clang::FunctionDecl *op);

	Document &m_document;
	std::string m_className;
};

#endif // OPERATOR_MATCH_HANDLER_HPP
