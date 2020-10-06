#include <cstdint>

enum TopLevel {
  A,
  B = A,
  C = -1,
};

namespace NS1 {
  enum InnerEnum { X };

  namespace NS2 {
    enum InnerEnum2 { X };
  }
}

enum U8Enum : uint8_t {
  D,
  E = (uint8_t)-1,
};



template <typename T>
class QFlags { };

enum FlagEnum {
  None = 0x00,
  P = 0x01,
  Q = 0x04,
  R = 0x0C,
};

template class QFlags<FlagEnum>;
typedef QFlags<FlagEnum> Flags;



struct Nested {
  enum { X = 10, Y = 20 };
};

struct Renamed {
  enum { Z = 30 };
};
