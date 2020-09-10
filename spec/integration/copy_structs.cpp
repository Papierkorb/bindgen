struct Point {
  Point(int x, int y) : x(x), y(y) { } // for instance_properties.cpp

  int x, y;
};

struct Line {
  Point v1, v2;
};

struct PolyLine {
  Line *line;
  PolyLine *before, *after;
};

struct Nested {
  struct Inner {
    float a;
  };
  struct Inner2 {
    float b;
  } c;
};

struct Anonymous {
  struct {
    struct {
      int x0; // .x0
    };
    struct {
      int x1; // .p0.x1
    } p0;
  };
  struct {
    struct {
      int x2; // .p2.x2
    };
    struct {
      int x3; // .p2.p1.x3
    } p1;
  } p2;
};

// these fields should not be copied
struct Wrapped {
  struct {
    int x;
  };
  struct {
    int y;
  } z;
};
