module Bindgen
  module Crystal
    # Argument naming logic.  This is not a `struct`.
    struct Argument
      def initialize(@db : TypeDatabase)
      end

      # Helper to get a non-colliding *argument* name.  Makes sure that the name
      # doesn't collide with a Crystal keyword.
      def name(name : String, idx) : String
        name = name.underscore
        name = "unnamed_arg_#{idx}" if name.empty?
        name = "#{name}_" if Crystal::KEYWORDS.includes?(name)
        name
      end

      # ditto
      def name(argument : Parser::Argument, idx)
        name(argument.name, idx)
      end

      # ditto
      def name(argument : Call::Argument, idx)
        name(argument.name, idx)
      end

      # Returns the `_self_` argument for the *method*, used in bindings.
      def self(klass_type : Parser::Type) : Call::Argument
        typename = Typename.new(@db)
        type_name, _ = typename.binding(klass_type)

        Call::Argument.new(
          type: klass_type,
          type_name: type_name,
          name: "_self_",
          call: "self",
          reference: false,
          pointer: 1, # It's always a pointer
        )
      end
    end
  end
end
