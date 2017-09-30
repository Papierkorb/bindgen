module Bindgen
  module CallBuilder
    # Builds a `QObject::connect` sequence.
    class CppQobjectConnect
      def initialize(@db : TypeDatabase)
      end

      def build(method : Parser::Method, proc)
        pass = Cpp::Pass.new(@db)

        Call.new(
          origin: method,
          name: "#{method.class_name}::#{method.name}",
          arguments: pass.arguments_from_cpp(method.arguments),
          result: pass.to_crystal(Processor::Qt::CONNECTION_HANDLE_TYPE),
          body: Body.new(proc),
        )
      end

      class Body < Call::Body
        def initialize(@proc : Call)
        end

        def to_code(call : Call, platform : Graph::Platform) : String
          formatter = Cpp::Format.new
          ptr = formatter.function_pointer(@proc)
          lambda_args = formatter.argument_list(call.arguments)

          inner = @proc.body.to_code(@proc, platform)
          code = %[QObject::connect(_self_, (#{ptr})&#{call.name}, [_proc_](#{lambda_args}){ #{inner}; })]

          if templ = call.result.conversion
            code = Util.template(templ, code)
          end

          code
        end
      end
    end
  end
end
