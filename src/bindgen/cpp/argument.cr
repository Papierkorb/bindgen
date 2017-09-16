module Bindgen
  module Cpp
    # Argument naming logic.  This is not a `struct`.
    module Argument
      # Helper to get a non-colliding *argument* name.
      def self.name(argument, idx : Int) : String
        name(argument.name, idx)
      end

      def self.name(argument : String, idx : Int) : String
        if argument.empty?
          "unnamed_arg_#{idx}"
        else
          argument
        end
      end

      # Returns the `_self_` argument for the *method*.
      def self.self(klass_type : Parser::Type) : Call::Argument
        Call::Argument.new(
          type: klass_type,
          type_name: klass_type.full_name,
          name: "_self_",
          call: "self",
          reference: false,
          pointer: 1, # It's always a pointer
        )
      end
    end
  end
end
