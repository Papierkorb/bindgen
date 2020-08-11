/* Note: Used by `inheritance_spec.cr` and `virtual_override_spec.cr`. */

struct Base {
  virtual int calc(int a, int b) {
    return a + b;
  }

  virtual int randomNumber() {
    return 4; // chosen by fair dice roll.
              // guaranteed to be random.
  }

  Base *belongToUs() {
    return this;
  }
};

struct AbstractThing {
  virtual const char *name() const = 0;

  int normalMethodInAbstractThing() {
    return 1;
  }

  AbstractThing *itself() {
    return this;
  }
};

struct Subclass : public Base, public AbstractThing {
  int calc(int a, int b) override {
    return a * b;
  }

  // We don't override Base::randomNumber here.

  const char *name() const override {
    return "Hello";
  }

  int callVirtual(int a, int b) {
    return this->calc(a, b);
  }

  int normalMethod() {
    return 1;
  }
};

struct Skip {
  virtual int ignoreThis() const {
    return 7;
  }
};
