module Bindgen
  module CallAnalyzer
    # Analyzer for calls made from C++ to C++.  Used by virtual methods to call
    # the implementation given in the base-class.
    class CppToCpp
      include CppMethods

      def initialize(@db : TypeDatabase)
      end

      def analyze(method : Parser::Method) : Call
        call_name = "#{method.class_name}::#{method.name}"

        arguments = method.arguments.map_with_index do |arg, idx|
          passthrough(arg).to_argument(argument_name(arg, idx))
        end

        result = passthrough(method.return_type)

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
