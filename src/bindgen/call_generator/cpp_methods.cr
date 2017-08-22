module Bindgen
  module CallGenerator
    # Helper methods for C++ centric generators.
    module CppMethods
      include Helper

      # Generates the `func_args` and `pass_args` for a call.
      def cpp_arguments(call, needs_instance)
        func_args = [ ] of String
        pass_args = [ ] of String

        func_args << "#{call.origin.class_name} *_self_" if needs_instance

        call.arguments.each do |arg|
          func_args << "#{cpp_typename(arg)} #{arg.name}"
          pass_args << arg.call
        end

        { func_args, pass_args }
      end

      # Generates the fully qualified C++ type-name of *var*.
      def cpp_typename(var)
        prefix = "const " if var.type.const?
        suffix = "*" * var.pointer
        suffix += "&" if var.reference

        "#{prefix}#{var.type_name}#{suffix}"
      end

      # Formats the *call* as `CrystalProc<...>` template type for C++.
      def cpp_crystal_proc(call) : String
        types = [ cpp_typename(call.result) ]
        types.concat call.arguments.map{|arg| cpp_typename arg}

        "CrystalProc<#{types.join(", ")}>"
      end
    end
  end
end
