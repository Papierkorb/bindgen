module Bindgen
  module CallBuilder
    # Builds an `abstract def`.
    class CrystalAbstractDef
      def initialize(@db : TypeDatabase)
      end

      def build(method : Parser::Method)
        pass = Crystal::Pass.new(@db)
        arguments = pass.arguments_to_wrapper(method.arguments)

        Call.new(
          origin: method,
          name: method.crystal_name,
          arguments: arguments,
          result: pass.from_wrapper(method.return_type),
          body: Body.new(@db),
        )
      end

      class Body < Call::Body
        def initialize(@db : TypeDatabase)
        end

        def to_code(call : Call, platform : Graph::Platform) : String
          method = Crystal::Method.new(@db)
          method.prototype(
            name: call.name,
            arguments: call.arguments,
            result: call.result,
            static: call.origin.static_method?,
            abstract: true,
            protected: call.origin.protected?,
          )
        end
      end
    end
  end
end
