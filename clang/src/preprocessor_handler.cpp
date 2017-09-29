#include "common.hpp"
#include "preprocessor_handler.hpp"

static llvm::cl::opt<std::string> MacroChecker("m", llvm::cl::desc("Macros to copy"), llvm::cl::value_desc("regex"));

PreprocessorHandler::PreprocessorHandler(std::vector<Macro> &macros, clang::Preprocessor &preprocessor)
		: m_macros(macros), m_preprocessor(preprocessor), m_regex(MacroChecker)
{
}

bool PreprocessorHandler::isMacroInteresting(const std::string &name) {
	std::smatch ignored_match;

	if (std::regex_match(name, ignored_match, this->m_regex)) {
  	return true;
	} else {
		return false;
	}
}

void PreprocessorHandler::MacroDefined(const clang::Token &token, const clang::MacroDirective *md) {
	if (md->getMacroInfo()->isBuiltinMacro())
		return;

  std::string name = token.getIdentifierInfo()->getName();
  if (!isMacroInteresting(name)) {
    return; // Skip!
  }

  // Store it
	Macro m;
  m.name = name;

  if (initializeMacro(m, token, md)) {
    this->m_macros.push_back(m);
  }
}

static void tryCopyArguments(Macro &m, const clang::MacroInfo *info) {
	if (info->param_empty()) return;

  auto iter = info->param_begin();
  for (auto end = info->param_end(); iter + 1 != end; ++iter) {
    m.arguments.push_back((*iter)->getName());
  }

  // Last argument may be a var-arg identifier.
  if ((*iter)->getName() == "__VA_ARGS__") {
    m.isVarArg = true;
  } else {
    m.arguments.push_back((*iter)->getName());
  }
}

static std::string readMacroValue(const clang::MacroInfo *info, clang::Preprocessor &preprocessor) {
  llvm::SmallString<128> spellingBuffer;
  std::string buffer;
  llvm::raw_string_ostream value(buffer);

  bool first = true;
	for (const auto &token : info->tokens()) {
		if (!first && token.hasLeadingSpace())
			value << ' ';

    first = false;
		value << preprocessor.getSpelling(token, spellingBuffer);
	}

  return value.str();
}

bool PreprocessorHandler::initializeMacro(Macro &m, const clang::Token &token, const clang::MacroDirective *md) {
  const clang::IdentifierInfo *identifier = token.getIdentifierInfo();
  const clang::MacroInfo *info = md->getMacroInfo();

  m.isFunction = info->isFunctionLike();
  m.isVarArg = false;

  tryCopyArguments(m, info);
  m.value = readMacroValue(info, this->m_preprocessor);

  if (info->isGNUVarargs()) {
    return false; // TODO: Support GNU var-args extension
  }

  return true; // Okay!
}
