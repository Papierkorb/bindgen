/* Note: Used by `copy_structs_spec.cr` and `instance_properties_spec.cr`. */

struct Point {
  Point(int x, int y) : x(x), y(y) { }

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



union PlainUnion {
  int x;
  float y;
};

// neither union should be inlined
struct UnionInStruct {
  union {
    char a;
    int b;
  } u;
  union {
    float c;
    bool d;
  };
};

// neither struct should be inlined
union StructInUnion {
  struct {
    char a;
    int b;
  } s;
  struct {
    float c;
    bool d;
  };
};

// c and d can be inlined
union NestedUnion {
  union {
    char a; // .u.a
    int b; // .u.b
  } u;
  union {
    float c; // .c
    bool d; // .d
  };
};



class Props {
public:
  Props(int x, int y) :
    x_pub(x), y_pub(y),
    x_prot(x + 100), y_prot(y + 100),
    x_priv(x + 200), y_priv(y + 200)
  {
    (void)x_priv; // silence -Wunused-private-field
    (void)y_priv;
  }

  int x_pub;
  const int y_pub;
  Point *position_ptr = new Point(12, 34);
  Point position_val {13, 35};

protected:
  int x_prot;
  const int y_prot;

private:
  int x_priv;
  const int y_priv;
};

struct ConfigIgnoreAll {
  const int a, b;
};

struct ConfigIgnore {
  const int a, b;
};

struct ConfigRename {
  const int m_iVar, m_iAnotherVar, x;
};

struct ConfigNilable {
  ConfigNilable() = default;

  bool *bool_ptr;
  Point *point_ptr;
};
