#ifndef MACRO_AST_CONSUMER_HPP
#define MACRO_AST_CONSUMER_HPP

#include "clang/AST/ASTConsumer.h"
#include "structures.hpp"
#include <vector>

class MacroAstConsumer : public clang::ASTConsumer {
public:

	MacroAstConsumer(std::vector<Macro> &macros);

	void checkVarDecl(clang::VarDecl *var, clang::ASTContext &ctx);

	void HandleTranslationUnit(clang::ASTContext &ctx) override;

private:
	std::vector<Macro> &m_macros;
};

#endif // MACRO_AST_CONSUMER_HPP
