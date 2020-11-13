#ifndef BINDGEN_AST_CONSUMER_HPP
#define BINDGEN_AST_CONSUMER_HPP

class RecordMatchHandler;
class OperatorMatchHandler;
class EnumMatchHandler;
class FunctionMatchHandler;

class BindgenASTConsumer : public clang::ASTConsumer {
public:
	BindgenASTConsumer(Document &doc, clang::CompilerInstance &compiler);

	~BindgenASTConsumer() override;

	void HandleTranslationUnit(clang::ASTContext &ctx) override;

private:
	clang::ast_matchers::MatchFinder makeBasicMatchFinder();
	clang::ast_matchers::MatchFinder makeDependentMatchFinder();

	void gatherTypeInfo(clang::ASTContext &ctx);
	void evaluateMacros(clang::ASTContext &ctx);
	void serializeAndOutput();

	clang::CompilerInstance &m_compiler;
	std::vector<std::unique_ptr<RecordMatchHandler>> m_classHandlers;
	std::vector<std::unique_ptr<OperatorMatchHandler>> m_operatorHandlers;
	std::vector<std::unique_ptr<EnumMatchHandler>> m_enumHandlers;
	std::unique_ptr<FunctionMatchHandler> m_functionHandler;
	Document &m_document;
	clang::ast_matchers::MatchFinder::MatchFinderOptions m_matchFinderOpts;
	std::vector<clang::ast_matchers::MatchFinder> m_matchFinders;
};

#endif // BINDGEN_AST_CONSUMER_HPP
