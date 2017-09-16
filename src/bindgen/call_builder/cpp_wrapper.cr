module Bindgen
  module CallBuilder
    # Builds a `Call` implementing a common C/C++ wrapper function.
    class CppWrapper
      def initialize(@db : TypeDatabase)
      end

      def build(method : Parser::Method, target : Call, self_var = "_self_", needs_instance = nil)
        pass = Cpp::Pass.new(@db)

        if needs_instance.nil?
          needs_instance = method.needs_instance?
        end

        arguments = pass.arguments_to_cpp(method.arguments)
        if needs_instance # Add `_self_`
          klass_type = Parser::Type.parse(method.class_name, 1)
          arguments.unshift(Cpp::Argument.self(klass_type))
        end

        Call.new(
          origin: method,
          name: method.mangled_name,
          arguments: arguments,
          result: pass.to_crystal(method.return_type),
          body: Body.new(target),
        )
      end

      class Body < Call::Body
        def initialize(@target : Call)
        end

        def to_code(call : Call, platform : Graph::Platform) : String
          formatter = Cpp::Format.new
          typer = Cpp::Typename.new
          func_result = typer.full(call.result)
          func_args = formatter.argument_list(call.arguments)

          %[extern "C" #{func_result} #{call.name}(#{func_args}) {\n] \
          %[  return #{@target.body.to_code(@target, platform)};\n] \
          %[}\n\n]
        end
      end
    end
  end
end
