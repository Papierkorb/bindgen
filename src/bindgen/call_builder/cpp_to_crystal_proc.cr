module Bindgen
  module CallBuilder
    # Builder for calls made from C++ to Crystal.  Used for callbacks, Qt
    # signals and virtual method overrides.
    class CppToCrystalProc
      def initialize(@db : TypeDatabase)
      end

      # Calls the *method*, using the *proc_name* to call-through to Crystal.
      def build(method : Parser::Method, proc_name : String = "_proc_") : Call
        pass = Cpp::Pass.new(@db)

        arguments = pass.arguments_from_cpp(method.arguments)
        result = pass.to_cpp(method.return_type)

        Call.new(
          origin: method,
          name: proc_name,
          result: result,
          arguments: arguments,
          body: Body.new,
        )
      end

      class Body < Call::Body
        def to_code(call : Call, platform : Graph::Platform) : String
          pass_args = call.arguments.map(&.call).join(", ")

          %[#{call.name}(#{pass_args})]
        end
      end
    end
  end
end
