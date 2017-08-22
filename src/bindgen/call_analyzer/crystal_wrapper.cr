module Bindgen
  module CallAnalyzer
    # Analyzer for calls made from the Crystal wrapper to a `lib` Binding.
    class CrystalWrapper
      include CrystalMethods

      def initialize(@db : TypeDatabase)
      end

      # By setting *instance_name*, this analyzer can be used to generate a call
      # to the *method*.  Otherwise, it's useful to generate a wrapper method.
      def analyze(method : Parser::Method, instance_name = nil, prefix = nil) : Call
        arguments = method.arguments.map_with_index do |arg, idx|
          pass_to_wrapper(arg).to_argument(argument_name(arg, idx))
        end

        result = pass_from_wrapper(method.return_type, method.any_constructor?)

        if instance_name
          prefix = "#{instance_name}.#{prefix}"
        elsif method.static_method?
          prefix = "self.#{prefix}"
        end

        Call.new(
          origin: method,
          name: "#{prefix}#{method.crystal_name}",
          result: result,
          arguments: arguments,
        )
      end
    end
  end
end
