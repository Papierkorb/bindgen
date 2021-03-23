#include <vector>
#include <string>

typedef std::vector<unsigned char> bytearray;
typedef unsigned int rgb;

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

  bytearray chars() {
    return { 0x01, 0x04, 0x09 };
  }

  std::vector<rgb> palette() {
    return { 0xFF0000, 0x00FF00, 0x0000FF };
  }

  double sum(std::vector<double> list) {
    double d = 0;

    for (double c : list) {
      d += c;
    }

    return d;
  }
};
