module Bindgen
  module CallAnalyzer
    # Analyzer for calls made from Crystal to C++.  This is used for common
    # bindings of normal methods.
    class CrystalBinding
      include CrystalMethods

      def initialize(@db : TypeDatabase)
      end

      def analyze(method : Parser::Method, klass_type : Parser::Type?) : Call
        arguments = method.arguments.map_with_index do |arg, idx|
          pass_to_binding(arg).to_argument(argument_name(arg, idx))
        end

        # Add `_self_` argument if required
        if klass_type && method.needs_instance?
          arguments.unshift self_argument(klass_type)
        end

        result = pass_from_binding(method.return_type, method.any_constructor?)

        Call.new(
          origin: method,
          name: "Binding.#{method.mangled_name}",
          result: result,
          arguments: arguments,
        )
      end
    end
  end
end
