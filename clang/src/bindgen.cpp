#include "common.hpp"
#include "json_stream.hpp"

#include "record_match_handler.hpp"
#include "enum_match_handler.hpp"
#include "bindgen_ast_consumer.hpp"
#include "bindgen_frontend_action.hpp"

static llvm::cl::OptionCategory BindgenCategory("bindgen options");
#if __clang_major__ >= 10
static const llvm::opt::OptTable& Options(clang::driver::getDriverOptTable());
#else
static std::unique_ptr<llvm::opt::OptTable> Options(clang::driver::createDriverOptTable());
#endif
// See bindgen_ast_consumer.cpp for more

int main(int argc, const char **argv) {
	clang::tooling::CommonOptionsParser op(argc, argv, BindgenCategory);
	clang::tooling::ClangTool tool(op.getCompilations(), op.getSourcePathList());
	return tool.run(clang::tooling::newFrontendActionFactory<BindgenFrontendAction>().get());
}
