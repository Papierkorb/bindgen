module Bindgen
  module CallBuilder
    # Builds a `Call` implementing a C++ member method, for overriding C++
    # virtual methods from Crystal.
    class CppMethod
      def initialize(@db : TypeDatabase)
      end

      def build(method : Parser::Method, target : Call, virtual_target : Call, class_name : String? = nil)
        pass = Cpp::Pass.new(@db)
        class_name ||= method.class_name

        Call.new(
          origin: method,
          name: method.name,
          arguments: pass.arguments_from_cpp(method.arguments),
          result: pass.to_cpp(method.return_type),
          body: Body.new(class_name, target, virtual_target),
        )
      end

      class Body < Call::Body
        def initialize(@class : String, @target : Call, @virtual_target : Call)
        end

        def code_body(const, call, platform, prefix)
          %[  #{const}#{@class} *_self_ = this;\n] \
          %[  if (#{@virtual_target.name}.isValid()) {\n] \
          %[    #{prefix}#{@virtual_target.body.to_code(@virtual_target, platform)};\n] \
          %[  } else {\n] \
          %[    #{prefix}#{@target.body.to_code(@target, platform)};\n] \
          %[  }]
        end

        def to_code(call : Call, platform : Graph::Platform) : String
          formatter = Cpp::Format.new
          typer = Cpp::Typename.new
          func_result = typer.full(call.result)
          func_args = formatter.argument_list(call.arguments)

          # Returning a `void` from a void method generates a warning.
          prefix = "return " unless call.result.type.void?
          const = "const " if call.origin.const?

          %[#{func_result} #{call.name}(#{func_args}) #{const}override {\n] \
          %[#{code_body(const, call, platform, prefix)}\n] \
          %[}\n]
        end
      end
    end
  end
end
