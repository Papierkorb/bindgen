#ifndef BINDGEN_FRONTEND_ACTION_HPP
#define BINDGEN_FRONTEND_ACTION_HPPd

class BindgenFrontendAction : public clang::ASTFrontendAction {
public:
	bool BeginInvocation(clang::CompilerInstance &ci) override;

	std::unique_ptr<clang::ASTConsumer> CreateASTConsumer(clang::CompilerInstance &ci, llvm::StringRef file) override;
};

#endif // BINDGEN_FRONTEND_ACTION_HPPd
