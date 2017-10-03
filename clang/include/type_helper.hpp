#ifndef TYPE_HELPER_HPP
#define TYPE_HELPER_HPP

#include "structures.hpp"

namespace clang {
	class QualType;
	class ASTContext;
	class ParmVarDecl;
};

namespace TypeHelper {
	Type qualTypeToType(const clang::QualType &qt, clang::ASTContext &ctx);

	void qualTypeToType(Type &target, const clang::QualType &qt, clang::ASTContext &ctx);

	Argument processFunctionParameter(const clang::ParmVarDecl *decl);

	void addFunctionParameters(const clang::FunctionDecl *func, Method &m);
};

#endif // RECORD_MATCH_HANDLER_HPP
