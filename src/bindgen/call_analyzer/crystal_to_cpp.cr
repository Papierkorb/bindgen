module Bindgen
  module CallAnalyzer
    # Analyzer for calls made from Crystal to C++.  This is used for common
    # bindings of normal methods.
    class CrystalToCpp
      include CppMethods

      def initialize(@db : TypeDatabase)
      end

      def analyze(method : Parser::Method, klass_name : String? = nil, self_var = "_self_") : Call
        klass_name ||= method.class_name
        call_name = generate_method_name(method, klass_name, self_var)

        arguments = method.arguments.map_with_index do |arg, idx|
          pass_to_cpp(arg).to_argument(argument_name(arg, idx))
        end

        result = pass_to_crystal(method.return_type, method.any_constructor?)

        Call.new(
          origin: method,
          name: call_name,
          result: result,
          arguments: arguments,
        )
      end
    end
  end
end
