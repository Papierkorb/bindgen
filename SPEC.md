# Specification

This document specifies all rules bindgen uses to do conversions.  All have
an assigned paragraph number for easy referencing.

Rules **should** have one (or more) examples, showcasing its implications.

## §1. C/C++ Parsing

## §2. Crystal wrappers

### §2.1 Name rewriting

Methods for which no other sub-rule applies have their name underscored:
`addWidget() -> #add_widget`

#### §2.1.1 Getters

A getter method is a method which:

1. Returns something different than C++ `void`
2. Has no arguments
3. Starts with `get`

If those rules are fulfilled, then the `get` prefix is removed:
`getWindowTitle() -> #window_title`

This rule can be overriden by `§2.1.2 Boolean getters`.

#### §2.1.2 Boolean getters

A boolean getter is a method which:

1. Returns C++ `bool`
2. Has no arguments
3. Starts with `get` or `is` or `has`

If these rules are fulfilled, then:

* `get` prefix is removed: `getAwesome() -> #awesome?`
* `is` prefix is removed: `isEmpty() -> #empty?`
* `has` prefix is retained: `hasSpace() -> #has_space?`

#### §2.1.3 Setters

A setter is a method which:

1. Returns C++ `void`
2. Has exactly one argument
3. Starts with `set`

If these rules are fulfilled, then the `set` prefix is removed, and a Crystal
writer method is created: `setWindowTitle() -> #window_title=`

### §2.2 Arguments

#### §2.2.1 Conversion

A conversion from the wrapper towards the binding happens if any of:

* The `crystal_type` and the `binding_type` differs
* A `from_crystal` for the arguments type is configured
* A `converter` for the arguments type is configured

If a conversion happens, the precedence is as follows:

1. `from_crystal` is used if set
2. `converter` is used if set

Examples:

1. A type with both `from_crystal` and `converter` set would be wrapped
by using the `from_crystal` template: `my_from_crystal(arg_name)`.
2. A type with `converter` set would be wrapped by using the `converter` module:
   `MyConverter.unwrap(arg_name)`.

#### §2.2.2 Unnamed arguments

C++ allows the declaration of unnamed arguments, like this: `void foo(int)`.
To wrap these methods, such arguments are given a name like `unnamed_arg_X`,
where `X` is the zero-indexed index of the affected argument.

Given `void foo(int, int two, int)`, the generated wrapper prototype would look
like this: `foo(unnamed_arg_0 : Int32, two : Int32, unnamed_arg_2 : Int32)`.

#### §2.2.3 Argument renaming

If an argument has a name which is a reserved word in Crystal, it gets an
underscore (`_`) appended: `void foo(int next) -> foo(next_ : Int32)`.

### §2.3 Inheritance and abstract classes

Inheritance from wrapped C++ classes is replicated in Crystal.

For a C++ class to be used as base-class in the Crystal wrapper, all of these
have to be true:

1. The base-class is wrapped.
2. The base-class is publicly inherited.

#### §2.3.1 Single inheritance

The base-class is inherited in Crystal, mirroring the C++ definition.

```cpp
class Foo : public Bar { ... };
```

If both `Foo` and `Bar` are wrapped, the following wrapper will be generated:

```crystal
class Foo < Bar
  # ...
end
```

#### §2.3.2 Multiple inheritance

The Crystal wrapper class will inherit from the first of all base-classes.  All
following base-classes are wrapped through an `#as_X` conversion method.

```cpp
class Foo : public Bar, public AnotherOne { ... };
```

Will generate:

```crystal
class Foo < Bar
  def as_another_one : AnotherOne
    # Conversion code ...
  end

  # ...
end
```

#### §2.3.3 Abstract classes

An abstract C++ class will also be declared `abstract` in Crystal.  Further,
an implementation class is generated to aid in conversion calls later on:

```cpp
class Foo { // A pure class
  virtual void doSomething() = 0;
};
```

Will be wrapped as:

```crystal
abstract class Foo
  abstract def do_something
end

class FooImpl < Foo
  def do_something
    # Call implementation ...
  end
end
```

**Note**: The `Impl` class cannot be inherited from.

#### §2.3.4 Virtual method override

It's possible to override a C++ method in a Crystal sub-class, if the C++ method
was defined as `virtual`.  A Crystal method is considered to override a C++
virtual method if the Crystal method and the C++ method share the same name.

```cpp
class Foo {
public:
  virtual int doWork() = 0;
};
```

Can be overriden from Crystal like this:

```crystal
class MyFoo < Foo # Inherit
  def do_work
    # ...
  end
end
```

The arguments and result values are proxied back and forth from C++ like normal
wrappers do.  The rules of argument handling is the same.  Such overrides will
look and behave the same to C++ as any other virtual C++ method.

**Note**: Calling `super` in the body of a Crystal method that overrides a
concrete C++ virtual method is not supported.  **The process will crash due to
a stack overflow!**

#### §2.3.5 Base-class wrapper

A `Superclass` wrapper is defined for every impure abstract class in C++.  This
wrapper is returned by the `#superclass` method; both the type and the method
are private within the original Crystal wrapper.  Concrete virtual methods of
the C++ type are mirrored in the superclass wrapper, except these methods always
invoke the original C++ methods, ignoring method overrides from Crystal.

```cpp
class Foo {
public:
  virtual int bar(int x);
  virtual int baz(int x) = 0;
};
```

Will generate:

```crystal
class Foo
  private class Superclass
    def bar(x)
      # ...
    end
  end

  private def superclass : Superclass
    # ...
  end
end
```

This allows sub-classes of `Foo` to do the following:

```crystal
class MyFoo < Foo
  def bar(x)
    superclass.bar(x) + superclass.bar(x - 1)
    # equivalent to: super + super(x - 1)
  end
end
```

**Note**: The wrapped methods always refer to the C++ methods.  If another class
inherits from `MyFoo` and overrides `#bar`, the overriding method may refer to
`MyFoo#bar` using `super` directly.

### §2.4 Instance properties

Property methods can be generated for an instance variable in a Crystal wrapper
if:

* The member's visibility is `public` or `protected` (the latter is mapped to
  `private` in Crystal)
* The member is not an lvalue or rvalue reference
* The type's `copy_structure` is not set
* The type's `instance_variable` settings do not reject the member

The getter is always defined for every instance variable, but the setter is
omitted if the instance variable was defined as a `const` member.  Property
methods are underscored.

```cpp
struct Point {
  int xPos, yPos;
protected:
  const int version;
};
```

Will be wrapped as: (implementations omitted)

```crystal
class Point
  def x_pos : Int32 end
  def x_pos=(x_pos : Int32) : Void end
  def y_pos : Int32 end
  def y_pos=(y_pos : Int32) : Void end
  private def version : Int32 end
end
```

### §2.4.1 Class type properties

If an instance variable is a value of another wrapped type, by default the
getter allocates a copy of the variable in C/C++ (using the C++ type's copy
constructor), so it is safe to modify the returned object without altering the
original instance.

```cpp
struct Line {
  Point start;
};
```

```crystal
class Line
  def start : Point end
  def start=(start : Point) : Void end
end

def start_from_zero(line : Line)
  # This has no effect!
  # `line.start` returns a copy of the property
  line.start.x_pos = 0
end
```

### §2.4.2 Pointer properties

If an instance variable is a pointer to a wrapped type, instances of the wrapped
type can be passed directly without forming any pointers.  These properties may
additionally be configured as nilable, in which case they may accept and return
`nil` as well, corresponding to C++'s `nullptr`.

```cpp
struct LinkedList {
  LinkedList *child;
  LinkedList *prev; // nilable
};
```

Generates:

```crystal
class LinkedList
  def child() : LinkedList end
  def child=(child : LinkedList) : Void end
  def prev() : LinkedList? end
  def prev=(child : LinkedList?) : Void end
end
```

Pointers of non-wrapped types, including primitive types, are exposed as Crystal
`Pointer(T)`s, and they are always nilable, using `Pointer(T).null` instead
of `nil`.

```cpp
struct OutParam {
  int *index;
  bool *found;
};
```

```crystal
class OutParam
  def index : Int32* end
  def index=(index : Int32*) : Void end
  def found : Bool* end
  def found=(found : Bool*) : Void end
end
```

## §3. Crystal bindings

### §3.1 Naming scheme

The bindings have to support method overloading, and as such use name mangling
to generate unique method names based on a method prototype.

The name consists out of the following parts (in this order):

1. `bg` prefix, marking it as bindgen wrapper function
2. The qualified C++ class name
3. Method type marker (See below)
4. The C++ method name
5. The mangled argument list (See below)

All of these parts are joined by a single underscore (`_`).

#### Argument type mangling

The argument list is a list of all types of the arguments, in the order they
appear in the method prototype.  Each argument types C++ name is taken and
transformed, such that:

1. A `*` is replaced with `X`
2. A `&` is replaced with `R`
3. All alpha-numeric characters are kept
4. All other characters are replaced with `_`

#### Method types

The method type marker mainly depends on the method type.  However, special
generated methods may use custom markers to distinguish them.

* Member methods don't have a marker
* Static methods use `STATIC`
* Constructors use `CONSTRUCT`
* Destructors use `DESTRUCT`

#### Examples

1. Member method `void Foo::bar(int *&) -> bg_Foo_bar_int_XR`
2. Static method: `void Foo::bar(std::string) -> bg_Foo_STATIC_bar_std__string`
3. Method without arguments: `void Foo::bar() -> bg_Foo_bar_` (Trailing `_`)

### §3.2 Structures

Structs marked with `copy_structure` are available under `lib Binding`.
Built-in types can be used directly, as are pointers to wrapped types.

```cpp
class Wrapper { }; // structure not copied

struct Point {
  int x, y;
  bool z;
  Wrapper *w;
};
```

```crystal
lib Binding
  struct Point
    x : Int32
    y : Int32
    z : Bool
    w : Wrapper* # refers to the return value of `Wrapper#to_unsafe`
  end
end
```

#### §3.2.1 Name rewriting

The names of a struct and its enclosing namespaces are CamelCased, and then
joined together by underscores (`_`).

* `Point` → `Point`
* `foo_bar` → `FooBar`
* `MyLib::core::val_array` → `MyLib_Core_ValArray`

#### §3.2.2 Nested anonymous types

Unnamed structs nested inside another struct are also copied, provided that the
struct names a data member and the enclosing type's structure is also copied.

```cpp
struct Outer {
  struct {
    int bar;
  } foo;
};

Outer { }.foo.bar; // => 0
```

```crystal
struct Outer
  foo : Outer_Unnamed0
end

struct Outer_Unnamed0
  bar : Int32
end

Binding::Outer.new.foo.bar # => 0
```

#### §3.2.3 Anonymous members

If the unnamed struct does not name a member, its contents are merged into the
enclosing type.

```cpp
struct Outer {
  struct {
    int bar;
  };
};

Outer().bar; // => 0
```

```crystal
struct Outer
  bar : Int32
end

Binding::Outer.new.bar # => 0
```

## §4. C++ wrapper functions

For each wrapped C++ function, there is at least one wrapper function generated.

## §5. Enumerations

### §5.1 Name rewriting

The name of an enum is constantized: `enum foo_bar` is translated as
`enum FooBar`.

### §5.2 Field name rewriting

The name of an enum constant is constantized: `color_0 -> Color0`.

### §5.3 Flag types

If an enumeration type is signaled to be a flags type, it'll get a `@[Flags]`
annotation in Crystal wrapper code.

Given a `QFlags<ApplicationFlag>`, the generated enumeration will look like

```cr
@[Flags]
enum ApplicationFlag : Int32
  # Constants ...
end
```

## §Q. Qt specifics

### §Q.1 QObject signals

QObject signals are wrapped in two methods: First, the emission method, and
second the connection method, which are then exposed as Crystal wrappers.

* Given this signal: `void changed(int one)`
* Emission method: `changed(one : Int32) : Void`
* Connection method: `on_changed(&block : Int32 -> Void)`

### §Q.1.1 Signal connection object

The connection method returns an connection object, which responds to
`#disconnect`.  Calling this method breaks the connection.  Subsequent calls to
this method have no effect.

### §Q.1.2 Overloaded signals

An overload is defined for each signature of a connection method that may take
different sets of parameters.  The overloads take the expected types of the
signal parameters, as mandatory function arguments.  This only happens to
overloaded signals; type arguments are not required for signals with unique
signatures.

* Given these signals:
  * `void changed(int one)`
  * `void changed(bool two)`
* Connection methods:
  * `on_changed(type1 : Int32.class, &block : Int32 -> Void)`
  * `on_changed(type1 : Bool.class, &block : Bool -> Void)`

### §Q.2 QFlags

`QFlags<EnumT>` is a C++/Qt template type marking a C++ `enum` to be a flags
type.  Once detected, the `clang` tool will mark the `enum` type as a flags
type.  See `§5.3 Flag types`.
