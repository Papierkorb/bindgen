struct Point {
  Point(int x, int y) : x(x), y(y) { }

  int x, y;
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

    v[2] = 2001;
    v2[4][3][2] = 2002;
  }

  int x_pub;
  const int y_pub;
  Point *position_ptr = new Point(12, 34);
  Point position_val {13, 35};

  int v[4] = { };
  int v2[5][6][7] = { };
  const int v_c[8] = {2003};
  int *v_ptr[9] = { };
  int *v2_ptr[10][11] = { };

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
