# Bindgen ![Logo](https://raw.githubusercontent.com/Papierkorb/bindgen/master/images/logo.png)

A (as of now) C++/Qt centric binding generator.

## Features

| Feature                                          | Support |
|--------------------------------------------------|---------|
| Automatic Crystal binding generation             | **YES** |
| Automatic Crystal wrapper generation             | **YES** |
| Mapping C++ classes                              | **YES** |
|  +- Member methods                               | **YES** |
|  +- Static methods                               | **YES** |
|  +- Constructors                                 | **YES** |
|  +- Overloaded operators                         |   TBD   |
|  +- Conversion functions                         |   TBD   |
| Mapping C functions                              | **YES** |
| Mapping OOP-like C APIs as Crystal classes       | **YES** |
| Overloaded methods (Also default arguments)      | **YES** |
| Copying default argument values                  |         |
|  +- Integer, float, boolean types                | **YES** |
|  +- String                                       | **YES** |
| Enumerations                                     | **YES** |
| Copying structures                               | **YES** |
| Custom type conversions between C/++ and Crystal | **YES** |
| Automatic type wrapping and conversion           | **YES** |
| Integration with Crystals GC                     | **YES** |
| C++ Template instantiation for containers types  | **YES** |
| Virtual methods                                  | **YES** |
| Override virtual methods from Crystal            | **YES** |
| Abstract classes                                 | **YES** |
| Multiple inheritance wrapping                    | **YES** |
| Qt integration                                   |         |
|  +- QObject signals                              | **YES** |
|  +- QFlags types                                 | **YES** |
|  +- QMetaObject generation (mimic `moc`)         |   TBD   |
| `#define` macro support                          |         |
|  +- Mapping as enumeration                       | **YES** |
|  +- Mapping as constant (Including strings)      | **YES** |
| Global functions                                 |   TBD   |
| Custom (de-)allocators                           |   TBD   |
| Copying in-source docs                           |   TBD   |
| Platform specific type binding rules             | **YES** |

## Projects using bindgen

* [Qt5 Bindings](https://github.com/Papierkorb/qt5.cr)

*Created a published, stable-y binding with bindgen?  Want to see it here?  PR!*

# How To

1. Add bindgen to your `shard.yml` and run `crystal deps`
2. Copy `assets/bindgen_helper.hpp` into your `ext/`
3. Copy and customize `TEMPLATE.yml`
4. Run `lib/bindgen/tool.sh your_template.yml`

```yaml
dependencies:
  bindgen:
    github: Papierkorb/bindgen
```

**Note**: If you intend to ship the generated code with your shard, you can
replace `dependencies` with `development_dependencies`.

See `TEMPLATE.yml` for configuration documentation.

# Mapping behaviour

The following rules are automatically applied to all bindings:

* Method names get underscored: `addWidget() -> #add_widget`
  * Setter methods are rewritten: `setWindowTitle() -> #window_title=`
  * Getter methods are rewritten: `getWindowTitle() -> #window_title`
  * Bool getters are rewritten: `getAwesome() -> #awesome?`
  * `is` getters are rewritten: `isEmpty() -> #empty?`
  * `has` getters are rewritten: `hasSpace() -> #has_space?`
* On signal methods (For Qt signals):
  * Keep their name for the `emit` version: `pressed() -> #pressed`
  * Get an `on_` prefix for the connect version: `#on_pressed do .. end`
* Enum fields get title-cased if not already: `color0 -> Color0`

# Processors

The processor pipeline can be configured through the `processors:` array.  Its
elements are run in the order they're defined, starting at the first element.

**Note**: Don't worry: The `TEMPLATE.yml` file already comes with the
recommended pipeline pre-configured.

There are three kinds of processors:
1. *Refining* ones modify the graph in some way, without a dependency to a later
   generator.
2. *Generation* processors add data to the graph so the later ran generators
   have all data they need to work.
3. *Information* processors don't modify the graph, but do checks or print data
   onto the screen for debugging purposes.

The order is having first *Refining*, and *Generation* processors second in the
configured pipeline.  *Information* processors can be run at any time.

The following list of processors is ordered alphabetically.

### `AutoContainerInstantiation`

* **Kind**: Refining
* **Run after**: No specific dependency
* **Run before**: `InstantiateContainers`

When encountering a known container class on an instantiation that is not
registered yet, registers it.

Container classes still need to be declared in the configuration, but don't
require an explicit `instantiations` attribute anymore:

```yaml
containers: # At the top-level of the config
  - class: QList # Set the class name
    type: Sequential # And its type
    # instantiations: # Can be added, but doesn't need to be.
```

### `CopyStructs`

* **Kind**: Refining
* **Run after**: No specific dependency
* **Run before**: No specific dependency

Copies structures of those types, that have `copy_structure: true` set in the
configuration.  A wrapper class of a `copy_structure` type will host the
structure directly (instead of a pointer) to it.

### `CppWrapper`

* **Kind**: Generation
* **Run after**: *Refining* processors
* **Run before**: `CrystalBinding`

Generates the C++ wrapper method `Call`s.

### `CrystalBinding`

* **Kind**: Generation
* **Run after**: `CppWrapper`, `VirtualOverride` and `CrystalWrapper`
* **Run before**: No specific dependency

Generates the `lib Binding` `fun`s.

### `CrystalWrapper`

* **Kind**: Generation
* **Run after**: *Refining* processors
* **Run before**:  `CrystalBinding` and `VirtualOverride`

Generates the Crystal methods in the wrapper classes.

### `DefaultConstructor`

* **Kind**: Refining
* **Run after**: No specific dependency
* **Run before**: No specific dependency

Clang doesn't expose default constructors methods for implicit default
constructors.  This processor finds these cases and adds an explicit constructor.

### `DumpGraph`

* **Kind**: Information
* **Run after**: Any time
* **Run before**: Any time

Debugging processor dumping the current graph onto `STDERR`.

### `FilterMethods`

* **Kind**: Refining
* **Run after**: No specific dependency
* **Run before**: No specific dependency

Removes all methods using an argument, or returning something, which is
configured as `ignore: true`.  Also removes methods that show up in the
`ignore_methods:` list.

This processor can be run at any time in theory, but should be run as first part
of the pipeline.

### `Functions`

* **Kind**: Refining
* **Run after**: `FunctionClass`
* **Run before**: No specific dependency

Maps C functions, configured through the `functions:` map in the configuration.

### `FunctionClass`

* **Kind**: Refining
* **Run after**: No specific dependency
* **Run before**: `Inheritance` and `Functions`

Generates wrapper classes from OOP-like C APIs, using guidance from the user
through configuration in the `functions:` map.

### `Inheritance`

* **Kind**: Refining
* **Run after**: `FunctionClass`
* **Run before**: `FilterMethods` and `VirtualOverride`

Implements Crystal wrapper inheritance and adds `#as_X` conversion methods.
Also handles abstract classes in that it adds an `Impl` class, so code can
return instances to the (otherwise) abstract class.

### `InstantiateContainers`

* **Kind**: Refining
* **Run after**: `AutoContainerInstantiation` if used
* **Run before**: No specific dependency

Adds the container instantiation classes and wrappers.

### `Macros`

* **Kind**: Refining
* **Run after**: No specific dependency
* **Run before**: No specific dependency

Maps `#define` macros into the graph.  The mapping is configured by the user in
the `macros:` list.  Only value-macros ("object-like macros") are supported,
function-like macros are silently skipped.

```c++
// Okay:
#define SOME_INT 1
#define SOME_STRING "Hello"
#define SOME_BOOL true

// Not mapped:
#define SOME_FUNCTION(x) (x + 1)
```

### `Qt`

* **Kind**: Refining
* **Run after**: No specific dependency
* **Run before**: No specific dependency

Adds Qt specific behaviour:

1. Removes the `qt_check_for_QGADGET_macro` fake method.
2. Provides `#on_SIGNAL` signal connection method.

```crystal
btn = Qt::PushButton.new
btn.on_clicked do |checked| # Generated by this processor
  puts "Checked: #{checked}"
end
```

### `SanityCheck`

* **Kind**: Information
* **Run after**: Any time, as very last pipeline element is ideal.
* **Run before**: Any time

Does sanity checks on the graph, focusing on Crystal bindings and wrappers.

Checks are as follows:
* Name of enums, libs, structures, classes, modules and aliases are valid
* Name of constants are valid
* Name of methods are valid
* Enumerations have at least one constant
* Flag-enumerations don't have `All` nor `None` constants
* Method arguments and result types are reachable
* Alias targets are reachable
* Class base-classes are reachable

### `VirtualOverride`

* **Kind**: Refining, but ran after generation processors!
* **Run after**: `CrystalWrapper`!
* **Run before**: `CrystalBinding` and `CppWrapper`

Adds C++ and Crystal wrapper code to allow overriding C++ virtual methods from
within Crystal.  Requires the `Inheritance` processor.

**Important Note**: Make sure to run this processor after `CrystalWrapper` but
before `CrystalBinding`.

It needs to modify the `#initialize` methods, and generate `lib` structures,
bindings, and C++ code too.

This is the recommended processor order:

```yaml
processors:
  # ...
  - crystal_wrapper
  - virtual_override
  - cpp_wrapper
  - crystal_binding
```

After this, usage is the same as with any method:

```crystal
class MyAdder < VirtualCalculator
  # In C++: virtual int calculate(int a, int b);
  # In Crystal:
  def calculate(a, b)
    a + b
  end
end
```

# Advanced configuration features

## Conditions and dependencies in YAML files

YAML configuration files support conditionals elements (So, `if`s), and loading
external dependency files.

Apart from this logic, the configuration file is still valid YAML.

**Note**: Conditionals and dependencies are *only* supported in
*mappings* (`Hash` in Crystal).  Any such syntax encountered in something
other than a *mapping* will not trigger any special behaviour.

### Condition syntax

YAML documents can define conditional parts in *mappings* by having a
conditional key, with *mapping* value.  If the condition matches, the
*mapping* value will be transparently embedded.  If it does not match, the
value will be transparently skipped.

Condition keys look like `if_X` or `elsif_X` or `else`.  `X` is the
condition, and it looks like `Y_is_Z` or `Y_match_Z`.  You can also use
(one or more) spaces (` `) instead of exactly one underscore (`_`) to
separate the words.

* `Y_is_Z` is true if the variable Y equals Z case-sensitively.
* `Y_isnt_Z` is true if the variable Y doesn't equal Z case-sensitively.
* `Y_match_Z` is true if the variable Y is matched by the regular expression
in `Z`.  The regular expression is created case-sensitively.

A condition block is opened by the first `if`.  Later condition keys can
use `elsif` or `else` (or `if` to open a *new* condition block).

**Note**: `elsif` or `else` without an `if` will raise an exception.

Their behaviour is like in Crystal: `if` starts a condition block, `elsif`
starts an alternative condition block, and `else` is used if none of `if` or
`elsif` matched.  It's possible to mix condition key-values with normal
key-values.

**Note**: Conditions can be used in every *mapping*, even in *mappings* of
a conditional.  Each *mapping* acts as its own scope.

#### Variables

Variables are set by the user of the class (Probably through
`ConfigReader.from_yaml`).  All variable values are strings.

Variable names are **case-sensitive**.  A missing variable will be treated
as having an empty value (`""`).

#### Examples

```yaml
foo: # A normal mapping
  bar: 1

# A condition: Matches if `platform` equals "arm".
if_platform_is_arm: # In Crystal: `if platform == "arm"`
  company: ARM et al

# You can mix in values between conditionals.  It won't "break" following
# elsif or else blocks.
not_a_condition: Hello

# An elsif: Matches if 1) the previous conditions didn't match
# 2) its own condition matches.
elsif_platform_match_x86: # In Crystal: `elsif platform =~ /x86/`
  company: Many different

# An else: Matches if all previous conditions didn't match.
else:
  company: No idea

# At any time, you can start a new if sequence.
"if today is friday": # You can use spaces instead of underscores too
  hooray: true
```

### Dependencies

To modularize the configuration, you can require ("merge") external yaml
files from within your configuration.

This is triggered by using a key named `<<`, and writing the file name as
value: `<<: my_dependency.yml`.  The file-extension can also be omitted:
`<<: my_dependency` in which case an `.yml` extension is assumed.

The dependency path is relative to the currently processed YAML file.

You can also require multiple dependencies into the same *mapping*:

```yaml
types:
  Something: true # You can mix dependencies with normal fields.
  <<: simple_types.yml
  <<: complex_types.yml
  <<: ignores.yml
```

The dependency will be embedded into the open *mapping*: It's transparent
to the client code.

It's perfectly possible to mix conditionals with dependencies:

```yaml
if_os_is_windows:
  <<: windows-specific.yml
```

#### Errors

An exception will be raised if any of the following occur:

* The maximum dependency depth of `10` (`MAX_DEPTH`) is exceeded.
* The dependency name contains a dot: `../foo.yml` won't work.
* The dependency name is absolute: `/foo/bar.yml` won't work.

# Architecture of bindgen

Bindgen employs a pipeline inspired code architecture, which is strikingly
similar to what most compilers use.

The code-flow is basically `Parser::Runner` to `Graph::Builder` to
`Processor::Runner` to `Generator::Runner`.

![Architecture flow diagram](https://raw.githubusercontent.com/Papierkorb/bindgen/master/images/architecture.png)

## The Graph

An important data structure used throughout the program is *the graph*.
Code-wise, it's represented by `Graph::Node` (And its sub-classes).  The nodes
can contain child nodes, making it a hierarchical structure.

This allows to represent (almost) arbitrary structures as defined by the user
configuration.

Say, we're wrapping `GreetLib`.  As any library, it comes with a bunch of
classes (`Greeter` and `Listener`), enums  (`Greetings`, `Type`) and other stuff
like constants (`PORT`).  The configuration file could look like this:

```yaml
module: GreetLib
classes: # We copy the structure of classes
  Greeter: Greeter
  Listener: Listener
enums: # But map the enums differently
  Type: Greeter::Type
  Greeter::Greetings: Greetings
```

Which will generate a graph looking like this:

![Graph example](https://raw.githubusercontent.com/Papierkorb/bindgen/master/images/graph.png)

**Note**: The concept is really similar to ASTs used by compilers.

## Parser step

Begin of the actual execution pipeline.  Calls out to the clang-based parser
tool to read the C/C++ source code and write a JSON-formatted "database" onto
standard output.  This is directly caught by `bindgen` and subsequently parsed
as `Parser::Document`.

## Graph::Builder step

The second step takes the `Parser::Document` and transforms it into a
`Graph::Namespace`.  This step is where the user configuration mapping is used.

## Processor step

The third step runs all configured processors in-order.  These work with the
`Graph` and mostly add methods and `Call`s so they can be bound later.  But
they're allowed to do whatever they want really, which makes it a good place
to add more complex rewriting rules if desired.

Processors are responsible for many core features of bindgen.  The `TEMPLATE.yml`
has an already set-up pipeline.

## Generator step

The final step now takes the finalized graph and writes the result into an
output of one or more files.  Generators do *not* change the graph in any way,
and also don't build anything on their own.  They only write to output.

## Contributing

1. Talk to `Papierkorb` in `#crystal-lang` about what you're gonna do.
2. You got the go-ahead?  The project's in an early state: Things may change without notice under you.
3. Read the `STYLEGUIDE.md` for some tips.
4. Then do the rest, PR and all.  You know the drill :)

## License

This project (`bindgen`) and all of its sources, except those otherwise noted,
all fall under the `GPLv3` license.  You can find a copy of its complete license
text in the `LICENSE` file.

The configuration used to generate code, and all code generated by this project,
fall under the full copyright of the user of `bindgen`.  `bindgen` does not
claim any copyright, legal or otherwise, on your work.  Established projects
should define a license they want to use for the generated code and
configuration.

## Contributors

- [Papierkorb](https://github.com/Papierkorb) Stefan Merettig - creator, maintainer
