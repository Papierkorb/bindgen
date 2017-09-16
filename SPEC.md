# Specification

This document specifies all rules bindgen uses to do conversions.  All have
an assigned paragraph number for easy referencing.

All rules **must** have one (or more) examples, showcasing its implications.

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

#### §2.2.4 Unnamed arguments

C++ allows the declaration of unnamed arguments, like this: `void foo(int)`.
To wrap these methods, such arguments are given a name like `unnamed_arg_X`,
where `X` is the zero-indexed index of the affected argument.

Given `void foo(int, int two, int)`, the generated wrapper prototype would look
like this: `foo(unnamed_arg_0 : Int32, two : Int32, unnamed_arg_2 : Int32)`.

#### §2.2.5 Argument renaming

If an argument has a name which is a reserved word in Crystal, it gets an
underscore (`_`) appended: `void foo(int next) -> foo(next_ : Int32)`.

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

**Argument type mangling**

The argument list is a list of all types of the arguments, in the order they
appear in the method prototype.  Each argument types C++ name is taken and
transformed, such that:

1. A `*` is replaced with `X`
2. A `&` is replaced with `R`
3. All alpha-numeric characters are kept
4. All other characters are replaced with `_`

**Method types**

The method type marker mainly depends on the method type.  However, special
generated methods may use custom markers to distinguish them.

* Member methods don't have a marker
* Static methods use `STATIC`
* Constructors use `CONSTRUCT`
* Destructors use `DESTRUCT`

**Examples**

1. Member method `void Foo::bar(int *&) -> bg_Foo_bar_int_XR`
2. Static method: `void Foo::bar(std::string) -> bg_Foo_STATIC_bar_std__string`
3. Method without arguments: `void Foo::bar() -> bg_Foo_bar_` (Trailing `_`)

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

### §Q.1.1

The connection method returns an connection object, which responds to
`#disconnect`.  Calling this method breaks the connection.  Subsequent calls to
this method have no effect.

### §Q.2 QFlags

`QFlags<EnumT>` is a C++/Qt template type marking a C++ `enum` to be a flags
type.  Once detected, the `clang` tool will mark the `enum` type as a flags
type.  See `§5.3 Flag types`.
