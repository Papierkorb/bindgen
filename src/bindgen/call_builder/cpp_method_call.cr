module Bindgen
  module CallBuilder
    # Builds a `Call` calling a C/C++ function without any conversions done to
    # the arguments or result.
    class CppMethodCall
      def initialize(@db : TypeDatabase)
      end

      def build(method : Parser::Method, self_var = "_self_", name : String? = nil)
        pass = Cpp::Pass.new(@db)

        method_name = Cpp::MethodName.new(@db)
        name ||= method_name.generate(method, self_var)

        Call.new(
          origin: method,
          name: name,
          arguments: pass.through_arguments(method.arguments),
          result: pass.through(method.return_type),
          body: CppCall::Body.new,
        )
      end
    end
  end
end
