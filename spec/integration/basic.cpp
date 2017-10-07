#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <gc/gc.h>

class IgnoreMe { };

class Adder {
  int base;
public:
  Adder(int b) : base(b) { }

  int sum(int offset) {
    return this->base + offset;
  }

  static int sum(int a, int b) {
    return a + b;
  }

  void ignoreByName() { }
  void ignoreByArgument(IgnoreMe me) { }
  void ignoreByArgumentRef(IgnoreMe &me) { }
  void ignoreByArgumentPtr(IgnoreMe *me) { }
  void ignoreByArgumentCRef(const IgnoreMe &me) { }
  void ignoreByArgumentCPtr(const IgnoreMe *me) { }
  IgnoreMe ignoreByReturn() { return IgnoreMe(); }
  IgnoreMe &ignoreByReturnRef() { return *new IgnoreMe(); }
  const IgnoreMe &ignoreByReturnCRef() { return *new IgnoreMe(); }
  IgnoreMe *ignoreByReturnPtr() { return new IgnoreMe(); }
  const IgnoreMe *ignoreByReturnCPtr() { return new IgnoreMe(); }
};

class TypeConversion {
public:

  char next(char c) {
    return c + 1;
  }

  // Specialized match in argument and result.  Result with decay.
  char *greet(const char *name) {
    int length = 31;
    char *buffer = static_cast<char *>(GC_malloc(length + 1));
    snprintf(buffer, length, "Hello %s!", name);
    return buffer;
  }

};

struct ImplicitConstructor {
  int itWorks() { return 1; }
};
