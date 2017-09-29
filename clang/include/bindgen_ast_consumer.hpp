#ifndef BINDGEN_AST_CONSUMER_HPP
#define BINDGEN_AST_CONSUMER_HPP

class RecordMatchHandler;
class EnumMatchHandler;

class BindgenASTConsumer : public clang::ASTConsumer {
public:
	BindgenASTConsumer(std::vector<Macro> &macros);

	~BindgenASTConsumer() override;

	void HandleTranslationUnit(clang::ASTContext &ctx) override;

private:

	void serializeEnumerations(JsonStream &stream);
	void serializeClasses(JsonStream &stream);

	std::vector<RecordMatchHandler *> m_classHandlers;
	std::vector<EnumMatchHandler *> m_enumHandlers;
	clang::ast_matchers::MatchFinder m_matchFinder;
	std::vector<Macro> &m_macros;
};

#endif // BINDGEN_AST_CONSUMER_HPP
