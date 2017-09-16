module Bindgen
  module CallBuilder
    # Builds a `Call` returning a single instance variable.
    class CrystalInstanceVariable
      def build(klass, name, result : Call::Result)
        method = Parser::Method.build(
          name: name,
          class_name: klass.name,
          return_type: result.type,
          arguments: [ ] of Parser::Argument,
        )

        Call.new(
          origin: method,
          name: name,
          arguments: [ ] of Call::Argument,
          result: result,
          body: Body.new(name),
        )
      end

      class Body < Call::Body
        def initialize(@name : String)
        end

        def to_code(_call : Call, _platform : Graph::Platform) : String
          %[@#{@name}]
        end
      end
    end
  end
end
