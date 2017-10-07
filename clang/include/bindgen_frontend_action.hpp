#ifndef BINDGEN_FRONTEND_ACTION_HPP
#define BINDGEN_FRONTEND_ACTION_HPP

class BindgenFrontendAction : public clang::ASTFrontendAction {
public:
	bool BeginInvocation(clang::CompilerInstance &ci) override;

	bool BeginSourceFileAction(clang::CompilerInstance &ci) override;

	std::unique_ptr<clang::ASTConsumer> CreateASTConsumer(clang::CompilerInstance &ci, llvm::StringRef file) override;

private:
	std::vector<Macro> m_macros;
};

#endif // BINDGEN_FRONTEND_ACTION_HPPd
