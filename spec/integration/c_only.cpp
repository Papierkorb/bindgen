extern "C" int extern_one() {
  return 1;
}

struct class_t { };

extern "C" {
  int extern_two() {
    return 2;
  }

  struct class_t *class_new() {
    return (struct class_t *)0;
  }

  int class_three(struct class_t *) {
    return 3;
  }

  int class_four() {
    return 4;
  }
}
