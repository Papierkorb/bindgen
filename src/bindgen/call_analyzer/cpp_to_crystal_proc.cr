module Bindgen
  module CallAnalyzer
    # Analyzer for calls made from C++ to Crystal.  Used for callbacks, Qt
    # signals and virtual method overrides.
    class CppToCrystalProc
      include CppMethods

      def initialize(@db : TypeDatabase)
      end

      # Calls the *method*, using the *proc_name* to call-through to Crystal.
      def analyze(method : Parser::Method, proc_name : String) : Call
        arguments = method.arguments.map_with_index do |arg, idx|
          pass_to_crystal(arg).to_argument(argument_name(arg, idx))
        end

        result = pass_to_cpp(method.return_type)

        Call.new(
          origin: method,
          name: proc_name,
          result: result,
          arguments: arguments,
        )
      end
    end
  end
end
