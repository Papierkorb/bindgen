#ifndef REGEX_HPP
#define REGEX_HPP

#include <pcre.h>
#include <string>

// PCRE based regex helper.  Aborts if a regex is broken.
class Regex {
public:
  Regex(const std::string &expression);
  Regex(const Regex &other);
  ~Regex();

  bool isMatch(const std::string &text) const;

private:
  pcre *m_regex;
  pcre_extra *m_extra;
};

#endif // REGEX_HPP
