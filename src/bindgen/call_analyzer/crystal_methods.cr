module Bindgen
  module CallAnalyzer
    # Helper methods for Crystal-centric call analyzers.
    module CrystalMethods
      include Helper
      extend self

      # All Crystal keywords
      CRYSTAL_KEYWORDS = %w[
        if while begin next end rescue ensure else def class struct lib module
        require require_relative return abstract include extend
      ]

      # The type-name of *type* for use in a wrapper.
      # The returned tuple contains the name first, and secondly, if the
      # type shall be looked-up in the `lib Binding` (= `true`), or not.
      def wrapper_typename(type : Parser::Type)
        rules = @db[type]?
        return { type.base_name, true } if rules.nil?

        # Only copied `struct`s reside in `Binding`!
        is_copied = rules.copy_structure

        if name = rules.crystal_type
          { name, false }
        elsif name = rules.binding_type
          { name, is_copied }
        else
          { type.base_name, is_copied }
        end
      end

      # Returns the qualified type-name of *type_name* from the output module.
      # If *in_lib* is `true`, the *type_name* is stored in `lib Binding`.  Else
      # it can is defined outside Binding, and thus doesn't need this prefix.
      def qualified_typename(type_name : String, in_lib : Bool) : String
        if in_lib
          "Binding::#{type_name}"
        else
          type_name
        end
      end

      # The type-name of *type* for use in a binding.
      def binding_typename(type : Parser::Type)
        rules = @db[type]?
        return { type.base_name, !type.builtin? } if rules.nil?

        in_lib = rules.copy_structure # Copied structures end up in Binding
        in_lib ||= !rules.kind.enum? && !rules.builtin && !type.builtin?

        if name = rules.lib_type
          { name, in_lib }
        else
          { type.base_name, in_lib }
        end
      end

      # Computes a result for passing *type* from Crystal to C++.
      def pass_to_binding(type : Parser::Type) : Call::Result
        pass_to(type) do |is_ref, ptr, type_name, nilable|
          if rules = @db[type]?
            template = type_template(rules.converter, rules.from_crystal, "wrap")
            type_name, _ = binding_typename(type)

            is_ref, ptr = reconfigure_pass_type(rules.pass_by, is_ref, ptr)
          end

          ptr += 1 if is_ref # Translate reference to pointer
          is_ref = false
          { is_ref, ptr, type_name, template, false }
        end
      end

      # Computes a result for passing *type* to the wrapper.
      def pass_to_wrapper(type : Parser::Type) : Call::Result
        pass_to(type) do |is_ref, ptr, type_name, nilable|
          if rules = @db[type]?
            type_name = qualified_typename(*wrapper_typename(type))

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

      def pass_to(type : Parser::Type) : Call::Result
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
      def pass_from_binding(type : Parser::Type, is_constructor = false) : Call::Result
        pass_from(type) do |is_ref, ptr, type_name, nilable|
          if rules = @db[type]?
            template = type_template(rules.converter, rules.to_crystal, "unwrap")
            type_name = qualified_typename(*binding_typename(type))
            is_ref, ptr = reconfigure_pass_type(rules.pass_by, is_ref, ptr)
          end

          { is_ref, ptr, type_name, template, false }
        end
      end

      # Computes a result for passing *type* from the wrapper to the user.
      def pass_from_wrapper(type : Parser::Type, is_constructor = false) : Call::Result
        pass_from(type) do |is_ref, ptr, type_name, nilable|
          if rules = @db[type]?
            type_name, in_lib = wrapper_typename(type)
            if in_lib
              type_name = "Binding::#{type_name}"
            end

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

      def pass_from(type : Parser::Type, is_constructor = false) : Call::Result
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

      def type_template(converter, translator, conv_name)
        if converter
          "#{converter}.#{conv_name}(%)"
        else
          translator
        end
      end

      # Returns the `Call::Result#conversion` template to turn a pointer into an
      # instance of *type_name* by using its `#initialize(unwrap: x)` method.
      def wrapper_initialize_template(type_name)
        "#{type_name}.new(unwrap: %)"
      end

      # Helper to get a non-colliding *argument* name.  Makes sure that the name
      # doesn't collide with a Crystal keyword.
      def argument_name(name : String, idx) : String
        name = name.underscore
        name = "unnamed_arg_#{idx}" if name.empty?
        name = "#{name}_" if CRYSTAL_KEYWORDS.includes?(name)
        name
      end

      # ditto
      def argument_name(argument : Parser::Argument, idx)
        argument_name argument.name, idx
      end

      # Returns the `_self_` argument for the *method*.
      def self_argument(klass_type : Parser::Type) : Call::Argument
        Call::Argument.new(
          type: klass_type,
          type_name: qualified_typename(*binding_typename(klass_type)),
          name: "_self_",
          call: "self",
          reference: false,
          pointer: 1, # It's always a pointer
        )
      end
    end
  end
end
