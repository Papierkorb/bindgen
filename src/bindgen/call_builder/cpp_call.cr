module Bindgen
  module CallBuilder
    # Builds a `Call` calling a C/C++ function.
    class CppCall
      def initialize(@db : TypeDatabase)
      end

      def build(
        method : Parser::Method, self_var = "_self_", body : Call::Body? = nil,
        name : String? = nil, braces : Bool = false
      )
        pass = Cpp::Pass.new(@db)

        if method.operator?
          name ||= self_var
          body ||= OperatorBody.new
        else
          method_name = Cpp::MethodName.new(@db)
          name ||= method_name.generate(method, self_var)
          body ||= braces ? BraceBody.new : Body.new
        end

        Call.new(
          origin: method,
          name: name,
          arguments: pass.arguments_to_cpp(method.arguments),
          result: pass.to_crystal(method.return_type),
          body: body,
        )
      end

      # Body used by `CppCall` and `CppMethodCall`.
      class Body < Call::Body
        def to_code(call : Call, _platform : Graph::Platform) : String
          pass_args = call.arguments.map(&.call).join(", ")
          code = %[#{call.name}(#{pass_args})]
          call.result.apply_conversion(code)
        end
      end

      # Body used for brace initialization.
      class BraceBody < Call::Body
        def to_code(call : Call, _platform : Graph::Platform) : String
          pass_args = call.arguments.map(&.call).join(", ")
          code = %[#{call.name} {#{pass_args}}]
          call.result.apply_conversion(code)
        end
      end

      # Body invoking a C++ operator.
      class OperatorBody < Call::Body
        def to_code(call : Call, _platform : Graph::Platform) : String
          case call.origin.binding_operator_name
          when "call"
            pass_args = call.arguments.map(&.call).join(", ")
            code = %[(*#{call.name})(#{pass_args})]
          when "succ", "pred", "plus", "neg", "deref", "bit_not", "not"
            op = call.origin.name[8..] # Remove `operator` prefix
            code = %[#{op}(*#{call.name})]
          when "post_succ", "post_pred"
            op = call.origin.name[8..]
            code = %[(*#{call.name})#{op}]
          when "at"
            pass_arg = call.arguments.first.call
            code = %{(*#{call.name})[#{pass_arg}]}
          else # remaining binary operators
            op = call.origin.name[8..]
            pass_arg = call.arguments.first.call
            code = %[(*#{call.name}) #{op} (#{pass_arg})]
          end

          call.result.apply_conversion(code)
        end
      end
    end
  end
end
