require "./value"

module Bindgen
  module Parser
    # Stores information on a C++ macro (a `#define`).
    class Macro
      include JSON::Serializable

      # List of macros.
      alias Collection = Array(Macro)

      # Name of the macro
      property name : String

      # If this is a function (`#define FOO(x, y) x + y`) or not
      property isFunction : Bool

      # If this function takes a variable amount of arguments
      property isVarArg : Bool

      # Argument names
      property arguments : Array(String)

      # The body of the macro, as written in the C/C++ source
      property value : String

      # The type of the evaluated macro body
      property type : Type?

      # If the macro was successfully evaluated, the parsed value.
      @[JSON::Field(converter: Bindgen::Parser::ValueConverter)]
      property evaluated : DefaultValueTypes?

      def initialize(@name, @isFunction, @isVarArg, @arguments, @value, @type, @evaluated)
      end

      # Is this macro function-like?
      def function? : Bool
        @isFunction
      end

      # Does this macro take a variable amount of arguments?
      def var_arg? : Bool
        @isVarArg
      end
    end
  end
end
