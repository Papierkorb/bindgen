module Bindgen
  module Crystal
    # Methods for passing data from Crystal and Crystal bindings to C++.
    #
    # This is a helper struct: Cheap to create and to pass around.
    struct Pass
      include TypeHelper

      def initialize(@db : TypeDatabase)
      end

      # Turns the list of arguments into a list of `Call::Argument`s.
      def arguments_to_binding(list : Enumerable(Parser::Argument))
        argument = Argument.new(@db)

        list.map_with_index do |arg, idx|
          to_binding(arg).to_argument(argument.name(arg, idx))
        end
      end

      # Turns the list of arguments into a list of `Call::Argument`s.
      def arguments_to_wrapper(list : Enumerable(Parser::Argument))
        argument = Argument.new(@db)

        list.map_with_index do |arg, idx|
          value = arg.value if arg.has_default?
          to_wrapper(arg).to_argument(argument.name(arg, idx), value)
        end
      end

      # Computes a result for passing *type* from Crystal to C++.  If
      # *to_unsafe* is `true`, and the type is not built-in, the result will
      # be wrapped in a call to `to_unsafe` - Except if a user-defined
      # conversion is set.
      def to_binding(type : Parser::Type, to_unsafe = false) : Call::Result
        to(type) do |is_ref, ptr, type_name, nilable|
          if rules = @db[type]?
            template = type_template(rules.converter, rules.from_crystal, "wrap")
            template ||= "%.to_unsafe" if to_unsafe && !rules.builtin && !type.builtin?

            type_name, _ = Typename.new(@db).binding(type)
            is_ref, ptr = reconfigure_pass_type(rules.pass_by, is_ref, ptr)
          end

          ptr += 1 if is_ref # Translate reference to pointer
          is_ref = false
          { is_ref, ptr, type_name, template, false }
        end
      end

      # Computes a result for passing *type* to the wrapper.
      def to_wrapper(type : Parser::Type) : Call::Result
        to(type) do |is_ref, ptr, type_name, nilable|
          if rules = @db[type]?
            typename = Typename.new(@db)
            type_name = typename.qualified(*typename.wrapper(type))

            if rules.kind.class?
              ptr -= 1 # It's a Crystal `Reference`.
            end

            is_ref, ptr = reconfigure_pass_type(rules.crystal_pass_by, is_ref, ptr)
          end

          ptr += 1 if is_ref # Translate reference to pointer
          is_ref = false
          { is_ref, ptr, type_name, nil, nilable }
        end
      end

      def to(type : Parser::Type) : Call::Result
        is_copied = is_type_copied?(type)
        is_ref = type.reference?
        is_val = type.pointer < 1
        ptr = type_pointer_depth(type)
        type_name = type.base_name
        nilable = type.nilable?

        # If the method expects a value, but we don't copy its structure, we pass
        # a reference to it instead.
        if is_val && !is_copied
          is_ref = true
          ptr = 0
        end

        # Hand-off
        is_ref, ptr, type_name, template, nilable = yield is_ref, ptr, type_name, nilable

        Call::Result.new(
          type: type,
          type_name: type_name,
          reference: is_ref,
          pointer: { 0, ptr }.max,
          conversion: template,
          nilable: nilable,
        )
      end

      # Computes a result for passing *type* from C++ to Crystal.
      #
      # If *qualified* is `true`, the type is assumed to be used outside the
      # `lib Binding`, and will be qualified if required.
      def from_binding(type : Parser::Type, qualified = false) : Call::Result
        from(type) do |is_ref, ptr, type_name, nilable|
          if rules = @db[type]?
            template = type_template(rules.converter, rules.to_crystal, "unwrap")
            typename = Typename.new(@db)

            if qualified
              type_name = typename.qualified(*typename.binding(type))
            else
              type_name, _ = typename.binding(type)
            end

            is_ref, ptr = reconfigure_pass_type(rules.pass_by, is_ref, ptr)
          end

          { is_ref, ptr, type_name, template, false }
        end
      end

      # Computes a result for passing *type* from the wrapper to the user.
      def from_wrapper(type : Parser::Type, is_constructor = false) : Call::Result
        from(type) do |is_ref, ptr, type_name, nilable|
          if rules = @db[type]?
            typename = Typename.new(@db)
            type_name, in_lib = typename.wrapper(type)
            type_name = typename.qualified(type_name, in_lib)

            if rules.kind.class?
              ptr -= 1
            end

            if !rules.builtin && !is_constructor && !rules.converter && !rules.to_crystal && !in_lib && !rules.kind.enum?
              template = wrapper_initialize_template(type_name)
            end

            is_ref, ptr = reconfigure_pass_type(rules.crystal_pass_by, is_ref, ptr)
          end

          ptr += 1 if is_ref # Translate reference to pointer
          is_ref = false
          { is_ref, ptr, type_name, template, nilable }
        end
      end

      def from(type : Parser::Type, is_constructor = false) : Call::Result
        is_copied = is_type_copied?(type)
        is_ref = type.reference?
        is_val = type.pointer < 1
        ptr = type_pointer_depth(type)
        type_name = type.base_name
        nilable = type.nilable?

        # TODO: Check for copy-constructor.
        if is_constructor && is_copied
          is_ref = false
          ptr = 0
        elsif is_ref || (is_val && !is_copied)
          is_ref = false
          ptr = 1
        end

        # Hand-off
        is_ref, ptr, type_name, template, nilable = yield is_ref, ptr, type_name, nilable
        ptr += 1 if is_ref # Translate reference to pointer

        Call::Result.new(
          type: type,
          type_name: type_name,
          reference: is_ref,
          pointer: { 0, ptr }.max,
          conversion: template,
          nilable: nilable,
        )
      end

      # Helper which chooses the *converter* if set, or falls back to the
      # *translator*.
      #
      # *converter* is set by the user as `converter:` field in the type
      # configuration, while *translator* is influenced by `to_crystal:` or
      # `from_crystal:`.
      private def type_template(converter, translator, conv_name)
        if converter
          "#{converter}.#{conv_name}(%)"
        else
          translator
        end
      end

      # Returns the `Call::Result#conversion` template to turn a pointer into an
      # instance of *type_name* by using its `#initialize(unwrap: x)` method.
      private def wrapper_initialize_template(type_name)
        "#{type_name}.new(unwrap: %)"
      end
    end
  end
end
