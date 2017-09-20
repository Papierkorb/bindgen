#include <string>

enum Numeral {
  First,
  Second,
};

class Defaults {
public:
  int defaultEnum(Numeral n = Second) {
    return static_cast<int>(n);
  }

  int defaultInt32(int n = 123) {
    return n;
  }

  void defaultTrue(bool n = true) { }
  void defaultFalse(bool n = false) { }

  int defaultString(std::string str = "Okay") {
    return str.length();
  }

  Defaults *nilable(Defaults *defaults = nullptr) {
    return defaults;
  }
};
