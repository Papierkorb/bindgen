module Bindgen
  module CallGenerator
    # Helper for Crystal-centric call generators.
    module CrystalMethods
      include Helper

      # Generates the `func_args` and `pass_args` for a call.
      def crystal_arguments(call, with_defaults = false)
        func_args = [ ] of String
        pass_args = [ ] of String

        call.arguments.each do |arg|
          func_args << crystal_argument(arg, with_defaults)
          pass_args << arg.call
        end

        { func_args, pass_args }
      end

      # Returns the notation of the *argument*, suitable for a wrapper.
      def crystal_argument(argument : Call::Argument, with_default = false) : String
        # Support the ampersand-prefix for `Call::ProcArgument#block?`
        prefix = "&" if argument.responds_to?(:block?) && argument.block?

        if with_default && argument.default_value != nil
          suffix = " = #{argument_value_to_literal(argument)}"
        end

        type_name = crystal_typename(argument)
        "#{prefix}#{argument.name} : #{type_name}#{suffix}"
      end

      # Turns the *argument*s default value into a literal.
      private def argument_value_to_literal(argument) : String
        formatter = CrystalLiteralFormatter.new(@db)

        value = argument.default_value.not_nil!

        # Try to format as built-in type
        if literal = formatter.literal(argument.type_name, value)
          return literal
        end

        # Try to format as wrapped Enum
        if value.is_a?(Number)
          literal = formatter.qualified_enum_name(argument.type, value.to_i)
          return literal if literal
        end

        raise "Can't format literal of default value (#{value.class}) " \
              "#{value.inspect} of argument #{argument.name.inspect} as " \
              "#{argument.type_name}"
      end

      # Generates the qualified type-name of *expr* for Crystal.  This includes
      # the resolved type-name itself, the pointer "stars", and a question-mark
      # if *expr* is `Call::Expression#nilable?`.
      def crystal_typename(expr : Call::Expression) : String
        suffix = "*" * expr.pointer
        suffix += "?" if expr.nilable?
        "#{expr.type_name}#{suffix}"
      end

      # Generates the declaration prefix of *method*.
      def method_type(method : Parser::Method, is_abstract) : String
        list = [ ] of String
        list << "private" if method.private?
        list << "protected" if method.protected?
        list << "abstract" if is_abstract
        list << "def"
        list.join(" ")
      end
    end
  end
end
