#include "common.hpp"
#include "bindgen_ast_consumer.hpp"

#include "clang/Parse/ParseAST.h"

#include "function_match_handler.hpp"
#include "record_match_handler.hpp"
#include "enum_match_handler.hpp"
#include "macro_ast_consumer.hpp"

static llvm::cl::list<std::string> ClassList("c", llvm::cl::desc("Classes to inspect"), llvm::cl::value_desc("class"));
static llvm::cl::list<std::string> EnumList("e", llvm::cl::desc("Enums to inspect"), llvm::cl::value_desc("enum"));

static clang::ast_matchers::MatchFinder::MatchFinderOptions OPTS = clang::ast_matchers::MatchFinder::MatchFinderOptions();

BindgenASTConsumer::BindgenASTConsumer(std::vector<Macro> &macros, clang::CompilerInstance &compiler, clang::ast_matchers::MatchFinder::MatchFinderOptions opts)
	: m_compiler(compiler), m_functionHandler(nullptr), m_macros(macros), m_matchFinder(opts)
{
	using namespace clang::ast_matchers;

	for (const std::string &className : ClassList) {
		DeclarationMatcher classMatcher = cxxRecordDecl(isDefinition(), hasName(className)).bind("recordDecl");

		RecordMatchHandler *handler = new RecordMatchHandler(className);
		this->m_matchFinder.addMatcher(classMatcher, handler);
		this->m_classHandlers.push_back(handler);
	}

	if (FunctionMatchHandler::isActive()) {
		DeclarationMatcher funcMatcher = functionDecl(unless(hasParent(cxxRecordDecl()))).bind("functionDecl");
		FunctionMatchHandler *handler = new FunctionMatchHandler();
		this->m_matchFinder.addMatcher(funcMatcher, handler);
		this->m_functionHandler = handler;
	}

	for (const std::string &enumName : EnumList) {
		DeclarationMatcher enumMatcher = enumDecl(hasName(enumName)).bind("enumDecl");
		DeclarationMatcher typedefMatcher = typedefNameDecl(hasName(enumName)).bind("typedefNameDecl");

		EnumMatchHandler *handler = new EnumMatchHandler(enumName);
		this->m_matchFinder.addMatcher(enumMatcher, handler);
		this->m_matchFinder.addMatcher(typedefMatcher, handler);
		this->m_enumHandlers.push_back(handler);
	}
}

BindgenASTConsumer::~BindgenASTConsumer() {
	for (RecordMatchHandler *handler : this->m_classHandlers) {
		delete handler;
	}
}

void BindgenASTConsumer::HandleTranslationUnit(clang::ASTContext &ctx) {
	this->m_matchFinder.matchAST(ctx);
	this->evaluateMacros(ctx);
	this->serializeAndOutput();
}

static std::string buildMacroEvaluationFile(const std::vector<Macro> &macros) {
	std::string backBuffer;
	llvm::raw_string_ostream stream(backBuffer);

	for (const Macro &macro : macros) {
		if (!macro.isFunction) {
			stream << "auto bg_macro_val_" << macro.name << " = (" << macro.name << ");\n";
		}
	}

	return stream.str();
}

void BindgenASTConsumer::evaluateMacros(clang::ASTContext &ctx) {
	clang::SourceManager &sourceMgr = this->m_compiler.getSourceManager();
	MacroAstConsumer *consumer = new MacroAstConsumer(this->m_macros);
	std::string evalFile = buildMacroEvaluationFile(this->m_macros);

	clang::FileID macroFile = sourceMgr.createFileID(llvm::MemoryBuffer::getMemBuffer(evalFile));
	sourceMgr.setMainFileID(macroFile);

	this->m_compiler.getDiagnostics().setClient(new clang::IgnoringDiagConsumer());
	clang::ParseAST(this->m_compiler.getPreprocessor(), consumer, ctx);
}

void BindgenASTConsumer::serializeAndOutput() {
	JsonStream stream(std::cout);

	stream << JsonStream::ObjectBegin; // {
	stream << "enums" << JsonStream::Separator; // "enums":
	serializeEnumerations(stream); // { ... }
	stream << JsonStream::Comma; // ,
	stream << "classes" << JsonStream::Separator; // "classes":
	serializeClasses(stream); // { ... }
	stream << JsonStream::Comma; // ,

	if (this->m_functionHandler) { // "functions": [ ... ],
		stream
			<< "functions" << JsonStream::Separator
			<< this->m_functionHandler->functions()
			<< JsonStream::Comma;
	}

	stream << "macros" << JsonStream::Separator << this->m_macros;  // "macros": [ ... ]
	stream << JsonStream::ObjectEnd; // }
}

void BindgenASTConsumer::serializeEnumerations(JsonStream &stream) {
	stream << JsonStream::ObjectBegin;

	bool first = true;
	for (EnumMatchHandler *handler : this->m_enumHandlers) {
		Enum enumeration = handler->enumeration();

		if (!first) stream << JsonStream::Comma;
		stream << std::make_pair(enumeration.name, enumeration);

		first = false;
	}

	stream << JsonStream::ObjectEnd;
}

void BindgenASTConsumer::serializeClasses(JsonStream &stream) {
	stream << JsonStream::ObjectBegin;

	bool first = true;
	for (RecordMatchHandler *handler : this->m_classHandlers) {
		Class klass = handler->klass();

		if (!first) stream << JsonStream::Comma;
		stream << std::make_pair(klass.name, klass);

		first = false;
	}

	stream << JsonStream::ObjectEnd;
}
