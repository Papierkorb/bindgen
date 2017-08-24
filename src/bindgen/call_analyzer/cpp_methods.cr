module Bindgen
  module CallAnalyzer
    # Shared code used by call generators calling from or to C++.
    module CppMethods
      include Helper
      extend self

      # Computes a result for passing *type* from Crystal to C++.
      def pass_to_cpp(type : Parser::Type) : Call::Result
        is_copied = is_type_copied?(type)
        is_ref = type.reference?
        is_val = type.pointer < 1
        ptr = type_pointer_depth(type)
        type_name = type.base_name

        # If the method expects a value, but we don't copy its structure, we pass
        # a reference to it instead.
        if is_val && !is_copied
          is_ref = true
          ptr = 0
        end

        if rules = @db[type]?
          template = rules.to_cpp
          type_name = rules.cpp_type || type_name
          is_ref, ptr = reconfigure_pass_type(rules.pass_by, is_ref, ptr)
        end

        Call::Result.new(
          type: type,
          type_name: type_name,
          reference: is_ref,
          pointer: ptr,
          conversion: template,
        )
      end

      # Computes a result for passing *type* from C++ to Crystal.
      def pass_to_crystal(type : Parser::Type, is_constructor = false) : Call::Result
        is_copied = is_type_copied?(type)
        is_ref = type.reference?
        is_val = type.pointer < 1
        ptr = type_pointer_depth(type)
        type_name = type.base_name

        # TODO: Check for copy-constructor.
        if is_constructor && is_copied
          is_ref = false
          ptr = 0
        elsif is_ref || (is_val && !is_copied)
          is_ref = false
          ptr = 1

          template = "new (UseGC) #{type.base_name} (%)"
        end

        if rules = @db[type]?
          # Support `from_cpp`.
          template = rules.from_cpp || template
          type_name = rules.cpp_type || type_name
          is_ref, ptr = reconfigure_pass_type(rules.pass_by, is_ref, ptr)
        end

        Call::Result.new(
          type: type,
          type_name: type_name,
          reference: is_ref,
          pointer: ptr,
          conversion: template,
        )
      end

      # Computes a result which is directly usable from C++ code, without
      # changes, and passes it through to crystal using conversion.
      def passthrough_to_crystal(type : Parser::Type)
        is_copied = is_type_copied?(type)
        is_ref = type.reference?
        is_val = type.pointer < 1
        ptr = type_pointer_depth(type)
        type_name = type.base_name

        # TODO: Check for copy-constructor.
        if is_ref || (is_val && !is_copied)
          # Don't change the external type (is_ref, ptr)!
          template = "new (UseGC) #{type.base_name} (%)"
        end

        if rules = @db[type]?
          # Support `from_cpp`.
          template = rules.from_cpp || template
        end

        Call::Result.new(
          type: type,
          type_name: type_name,
          reference: is_ref,
          pointer: ptr,
          conversion: template,
        )
      end

      # Generates the C++ *method* name.
      def generate_method_name(method, klass, self_var)
        case method
        when .copy_constructor?, .constructor?
          if is_type_copied?(method.class_name)
            klass
          else
            "new (UseGC) #{klass}"
          end
        when .member_method?, .signal?, .operator?
          "#{self_var}->#{method.name}"
        when .static_method?
          "#{method.class_name}::#{method.name}"
        else
          raise "Missing case for method type #{method.type.inspect}"
        end
      end

      # Helper to get a non-colliding *argument* name.
      def argument_name(argument : Parser::Argument, idx) : String
        name = argument.name
        name = "unnamed_arg_#{idx}" if name.empty?
        name
      end
    end
  end
end
