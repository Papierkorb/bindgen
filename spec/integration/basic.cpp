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
};
