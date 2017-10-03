/* Macro tests */
#define CONSTANT_ONE 1
#define CONSTANT_TWO 2
#define CONSTANT_THREE "Three"

#define ANOTHER_A "A"
#define ANOTHER_B "B"
#define ANOTHER_C "C"

#define ENUM_ONE 1
#define ENUM_TWO 2
#define ENUM_THREE 3

#define FLAGS_ONE 1
#define FLAGS_TWO 2
#define FLAGS_FOUR 4

/* Function mapping */

// Simple cases
int one() { return 1; }   // Short-hand
int two() { return 2; }   // Full name
int three() { return 3; } // Short-hand, One capture group
int four() { return 4; }  // One capture group

// Test simple name rewriting: /mycalc_(.*)/ -> "\1"
int mycalc_add(int a, int b) { return a + b; }
int mycalc_sub(int a, int b) { return a - b; }

// Test individual nesting: /thing_([^_]+)_(.*)/ -> "\1::\2"
int thing_increment_one(int v) { return v + 1; }
int thing_decrement_one(int v) { return v - 1; }
