module Bindgen
  module CallGenerator
    # Generates a `QObject::connect` call.
    class CppQObjectConnect
      include CppMethods

      # *call* should be created by `CallAnalyzer::CppToCrystalProc`
      def generate(conn_call : Call, lambda_call : Call) : String
        func_args, pass_args = cpp_arguments(lambda_call, false)
        invoc = invocation(lambda_call, pass_args)
        method = lambda_call.origin

        func_ptr = lambda_call.origin.function_pointer

        code = String.build do |b|
          b << %[QObject::connect(_self_, (#{func_ptr})&#{method.class_name}::#{method.name}, [_proc_](#{func_args.join(", ")}){\n]
          b << %[  #{invoc};\n]
          b << %[})]
        end

        invocation(conn_call, code)
      end
    end
  end
end
