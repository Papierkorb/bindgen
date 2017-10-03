#include "common.hpp"
#include "bindgen_ast_consumer.hpp"

#include "function_match_handler.hpp"
#include "record_match_handler.hpp"
#include "enum_match_handler.hpp"

static llvm::cl::list<std::string> ClassList("c", llvm::cl::desc("Classes to inspect"), llvm::cl::value_desc("class"));
static llvm::cl::list<std::string> EnumList("e", llvm::cl::desc("Enums to inspect"), llvm::cl::value_desc("enum"));

BindgenASTConsumer::BindgenASTConsumer(std::vector<Macro> &macros)
	: m_functionHandler(nullptr), m_macros(macros)
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
