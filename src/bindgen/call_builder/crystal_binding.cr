module Bindgen
  module CallBuilder
    # Builder for calls made from Crystal to C++.  This is used for common
    # bindings of normal methods.
    class CrystalBinding
      def initialize(@db : TypeDatabase)
      end

      # *explicit_binding* only affects the `FunBody`.
      def build(method : Parser::Method, klass_type : Parser::Type?, body = FunBody, explicit_binding : String? = nil) : Call
        pass = Crystal::Pass.new(@db)
        argument = Crystal::Argument.new(@db)

        arguments = pass.arguments_to_binding(method.arguments)

        # Add `_self_` argument if required
        if klass_type && method.needs_instance?
          arguments.unshift argument.self(klass_type)
        end

        result = pass.from_binding(method.return_type, is_constructor: method.any_constructor?)

        Call.new(
          origin: method,
          name: method.mangled_name,
          result: result,
          arguments: arguments,
          body: body.new(@db, explicit_binding),
        )
      end

      class FunBody < Call::Body
        def initialize(@db : TypeDatabase, @target : String?)
        end

        def to_code(call : Call, _platform : Graph::Platform) : String
          formatter = Crystal::Format.new(@db)
          typer = Crystal::Typename.new(@db)
          func_result = typer.full(call.result)
          func_args = formatter.argument_list(call.arguments)
          infix = " = #{@target}" if @target

          %[fun #{call.name}#{infix}(#{func_args}) : #{func_result}]
        end
      end

      class InvokeBody < Call::HookableBody
        def initialize(@db : TypeDatabase, _target)
        end

        def to_code(call : Call, platform : Graph::Platform) : String
          pre = @pre_hook
          post = @post_hook

          pass_args = call.arguments.map(&.call).join(", ")
          code = %[Binding.#{call.name}(#{pass_args})]

          if templ = call.result.conversion
            code = Util.template(templ, code)
          end

          # Support for pre- and post hooks.
          String.build do |b|
            b << pre.to_code(call, platform) << "\n" if pre
            if post
              b << "result = " << code << "\n"
              b << post.to_code(call, platform)
              b << "result" # Implicit return
            else
              b << code
            end
          end
        end
      end
    end
  end
end
