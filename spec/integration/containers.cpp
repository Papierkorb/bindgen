#include <vector>
#include <string>

class Containers {
public:
  std::vector<int> integers() {
    return std::vector<int>{ 1, 2, 3 };
  }

  std::vector<std::vector<int>> grid() {
    return { { 1, 4 }, { 9, 16 } };
  }

  std::vector<std::string> strings() {
    return std::vector<std::string>{ "One", "Two", "Three" };
  }

  double sum(std::vector<double> list) {
    double d = 0;

    for (double c : list) {
      d += c;
    }

    return d;
  }
};
