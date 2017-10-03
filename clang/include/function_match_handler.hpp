#ifndef FUNCTION_MATCH_HANDLER_HPP
#define FUNCTION_MATCH_HANDLER_HPP

#include "clang/ASTMatchers/ASTMatchFinder.h"
#include "structures.hpp"
#include <regex>

namespace clang {
	class FunctionDecl;
}

class FunctionMatchHandler : public clang::ast_matchers::MatchFinder::MatchCallback {
public:
	FunctionMatchHandler();
	static bool isActive();

	const std::vector<Method> &functions() const
	{ return this->m_functions; };

	virtual void run(const clang::ast_matchers::MatchFinder::MatchResult &Result) override;
	bool isFunctionInteresting(const std::string &name) const;
	void runOnFunction(const clang::FunctionDecl *func);

private:
	std::regex m_regex;
	std::vector<Method> m_functions;
};

#endif // FUNCTION_MATCH_HANDLER_HPP
