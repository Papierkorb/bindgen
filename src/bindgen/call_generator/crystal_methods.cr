module Bindgen
  module CallGenerator
    # Helper for Crystal-centric call generators.
    module CrystalMethods
      include Helper

      # Generates the `func_args` and `pass_args` for a call.
      def crystal_arguments(call)
        func_args = [ ] of String
        pass_args = [ ] of String

        call.arguments.each do |arg|
          prefix = "&" if arg.responds_to?(:block?) && arg.block?
          func_args << "#{prefix}#{arg.name} : #{crystal_typename(arg)}"
          pass_args << arg.call
        end

        { func_args, pass_args }
      end

      # Generates the qualified type-name of *var* for Crystal
      def crystal_typename(var)
        suffix = "*" * var.pointer
        "#{var.type_name}#{suffix}"
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
