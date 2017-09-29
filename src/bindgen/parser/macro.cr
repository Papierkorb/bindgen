module Bindgen
  module Parser
    # Stores information on a C++ macro (a `#define`).
    class Macro
      # List of macros.
      alias Collection = Array(Macro)

      JSON.mapping(
        # Name of the macro
        name: String,

        # If this is a function (`#define FOO(x, y) x + y`) or not
        isFunction: Bool,

        # If this function takes a variable amount of arguments
        isVarArg: Bool,

        # Argument names
        arguments: Array(String),

        # The body of the macro, as written in the C/C++ source
        value: String,
      )

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
