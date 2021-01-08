module Bindgen
  module Parser
    # Stores information on a C++ macro (a `#define`).
    class Macro
      include JSON::Serializable

      # List of macros.
      alias Collection = Array(Macro)

      # Name of the macro
      getter name : String

      # Is this macro function-like? (`#define FOO(x, y) x + y`)
      @[JSON::Field(key: "isFunction")]
      getter? function : Bool

      # Does this macro take a variable amount of arguments?
      @[JSON::Field(key: "isVarArg")]
      getter? var_arg : Bool

      # Argument names
      getter arguments : Array(String)

      # The body of the macro, as written in the C/C++ source
      getter value : String

      # The type of the evaluated macro body
      getter type : Type?

      # If the macro was successfully evaluated, the parsed value.
      @[JSON::Field(converter: Bindgen::Parser::ValueConverter)]
      getter evaluated : DefaultValueTypes?
    end
  end
end
