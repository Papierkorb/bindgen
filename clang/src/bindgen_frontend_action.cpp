#include "common.hpp"
#include "generated.hpp"

#include "bindgen_frontend_action.hpp"
#include "bindgen_ast_consumer.hpp"

bool BindgenFrontendAction::BeginInvocation(clang::CompilerInstance &ci) {
	clang::HeaderSearchOptions &headerOpts = ci.getHeaderSearchOpts();

	// Add built-in system include paths.
	for (const char *path : BG_SYSTEM_INCLUDES) {
		headerOpts.AddPath(llvm::StringRef(path), clang::frontend::System, false, false);
	}

	return true;
}

std::unique_ptr<clang::ASTConsumer> BindgenFrontendAction::CreateASTConsumer(clang::CompilerInstance &ci, llvm::StringRef file) {
	return llvm::make_unique<BindgenASTConsumer>();
}
