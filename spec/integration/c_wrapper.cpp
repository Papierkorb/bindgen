#include <cstdlib>
#include <cstring>

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

extern "C" {
// Test simple name rewriting: /mycalc_(.*)/ -> "\1"
int mycalc_add(int a, int b) { return a + b; }
int mycalc_sub(int a, int b) { return a - b; }

// Test individual nesting: /thing_([^_]+)_(.*)/ -> "\1::\2"
int thing_increment_one(int v) { return v + 1; }
int thing_decrement_one(int v) { return v - 1; }
} // extern "C"

// C-with-classes wrapper test
struct string_buffer {
  char *ptr;
  int size;
};

extern "C" {
string_buffer *buffer_new() { // Constructor
  string_buffer *buf = static_cast<string_buffer *>(malloc(sizeof(string_buffer)));
  buf->ptr = nullptr;
  buf->size = 0;
  return buf;
}

string_buffer *buffer_new_string(const char *string) { // Constructor
  string_buffer *buf = static_cast<string_buffer *>(malloc(sizeof(string_buffer)));
  buf->size = strlen(string);
  buf->ptr = static_cast<char *>(malloc(buf->size));
  memcpy(buf->ptr, string, buf->size);
  return buf;
}

void buffer_free(string_buffer *buf) { // Destructor
  free(buf->ptr);
  free(buf);
}

int buffer_size(string_buffer *buf) { // Member
  return buf->size;
}

char *buffer_string(string_buffer *buf) { // Member
  return buf->ptr;
}

void buffer_append(string_buffer *buf, const char *string) { // Member
  int added = strlen(string);

  buf->ptr = static_cast<char *>(realloc(buf->ptr, buf->size + added));
  memcpy(buf->ptr + buf->size, string, added);
  buf->size += added;
}

int buffer_version() { // Static
  return 123;
}

} // extern "C"
