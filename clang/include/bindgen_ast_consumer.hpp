#ifndef BINDGEN_AST_CONSUMER_HPP
#define BINDGEN_AST_CONSUMER_HPP

class RecordMatchHandler;
class EnumMatchHandler;
class FunctionMatchHandler;

class BindgenASTConsumer : public clang::ASTConsumer {
public:
	BindgenASTConsumer(std::vector<Macro> &macros, clang::CompilerInstance &compiler, clang::ast_matchers::MatchFinder::MatchFinderOptions opts);

	~BindgenASTConsumer() override;

	void HandleTranslationUnit(clang::ASTContext &ctx) override;

private:

	void evaluateMacros(clang::ASTContext &ctx);
	void serializeAndOutput();
	void serializeEnumerations(JsonStream &stream);
	void serializeClasses(JsonStream &stream);

	clang::CompilerInstance &m_compiler;
	std::vector<RecordMatchHandler *> m_classHandlers;
	std::vector<EnumMatchHandler *> m_enumHandlers;
	FunctionMatchHandler *m_functionHandler;
	std::vector<Macro> &m_macros;
	clang::ast_matchers::MatchFinder m_matchFinder;
};

#endif // BINDGEN_AST_CONSUMER_HPP
