#include <regex.hpp>

#include <cstdio>
#include <cstdlib>
#include <stdexcept>

static const int PCRE_FLAGS = 0;

static void errorAndBail(const char *message, const std::string &expression, const char *error, int offset) {
  fprintf(stderr, "%s:\n", message);
  fprintf(stderr, "  Error     : %s\n", error);
  fprintf(stderr, "  Expression: %s\n", expression.c_str());

  // Point to the error position
  if (offset >= 0) {
    fprintf(stderr, "              ");
    for (int i = 0; i < offset; i++)
      fputc(' ', stderr);
    fprintf(stderr, "^\n");
  }

  abort(); // Bail!
}

static void compileRegex(const std::string &expr, pcre *&regex, pcre_extra *&extra) {
  const char *error = nullptr;
  int offset = 0;

  regex = pcre_compile(expr.c_str(), PCRE_FLAGS, &error, &offset, nullptr);

  if (error || regex == nullptr) {
    errorAndBail("Bad regular expression", expr, error, offset);
  }

  extra = pcre_study(regex, 0, &error);

  if (error) { // m_extra can be NULL, and that's ok!
    errorAndBail("Failed to study expression", expr, error, -1);
  }

  pcre_refcount(regex, 1);
}

Regex::Regex(const std::string &expression)
  : m_regex(nullptr), m_extra(nullptr)
{
  // If the expression is empty, we don't want to match anything.
  if (!expression.empty()) {
    compileRegex(expression, this->m_regex, this->m_extra);
  }
}

Regex::Regex(const Regex &other) {
  this->m_regex = other.m_regex;

  if (this->m_regex) {
    pcre_refcount(this->m_regex, 1);
  }
}

Regex::~Regex() {
  if (this->m_regex && pcre_refcount(this->m_regex, -1) < 1) {
    pcre_free(this->m_regex);
    pcre_free_study(this->m_extra);
  }
}

bool Regex::isMatch(const std::string &text) const {
  if (this->m_regex == nullptr) return false;

  int r;

  r = pcre_exec(this->m_regex, this->m_extra, text.c_str(), text.size(), 0, 0, NULL, 0);

  if (r == PCRE_ERROR_NOMATCH) {
    return false;
  } else if (r >= 0) {
    return true; // Found a match!
  } else { // Unexpected error
    fprintf(stderr, "Regular expression failed with error %i\n", r);
    throw std::runtime_error("Regex error");
  }
}
