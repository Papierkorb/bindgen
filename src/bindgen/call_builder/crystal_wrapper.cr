module Bindgen
  module CallBuilder
    # Builds a `Call` implementing a common method calling a `CrystalBinding`
    # call.
    class CrystalWrapper
      def initialize(@db : TypeDatabase)
      end

      def build(method : Parser::Method, target : Call)
        pass = Crystal::Pass.new(@db)
        argument = Crystal::Argument.new(@db)

        arguments = pass.arguments_to_wrapper(method.arguments)
        if method.any_constructor?
          body = ConstructorBody.new(@db, target)
        else
          body = MethodBody.new(@db, target)
        end

        Call.new(
          origin: method,
          name: method.crystal_name,
          arguments: arguments,
          result: pass.from_wrapper(method.return_type),
          body: body,
        )
      end

      abstract class Body < Call::HookableBody
        def initialize(@db : TypeDatabase, @target : Call)
        end

        # Generates the call itself.
        abstract def encapsulate(call, code)

        # Support for pre- and post hooks.
        private def encapsulate_and_hook(call, platform, code)
          pre = @pre_hook
          post = @post_hook
          code = encapsulate(call, code)

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

        def to_code(call : Call, platform : Graph::Platform) : String
          formatter = Crystal::Format.new(@db)
          typer = Crystal::Typename.new(@db)
          func_result = typer.full(call.result)
          func_args = formatter.argument_list(call.arguments)

          code = @target.body.to_code(@target, platform)
          code = encapsulate_and_hook(call, platform, code)

          # Crystal doesn't like `#initialize` methods having an explicit return
          # type.
          unless call.origin.any_constructor?
            suffix = " : #{func_result}"
          end

          static = "self." if call.origin.static_method?
          kind = "protected " if call.origin.protected?

          %[#{kind}def #{static}#{call.name}(#{func_args})#{suffix}\n] \
          %[  #{code}\n] \
          %[end\n]
        end
      end

      class MethodBody < Body
        def encapsulate(call, code)
          if templ = call.result.conversion
            Util.template(templ, code)
          else
            code
          end
        end
      end

      class ConstructorBody < Body
        def encapsulate(call, code)
          %[result = #{code}\n] \
          %[@unwrap = result]
        end
      end
    end
  end
end
