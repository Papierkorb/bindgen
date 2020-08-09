module Bindgen
  module CallBuilder
    # Builder for the `#initialize` method inside a superclass wrapper.
    class CrystalSuperclassInit
      def initialize(@db : TypeDatabase)
      end

      def build(method : Parser::Method, parent_klass : Parser::Class) : Call
        myself = Call::Argument.new(
          type: parent_klass.as_type,
          type_name: parent_klass.name,
          name: "@myself",
          call: "@myself",
          reference: false,
          pointer: 0,
        )

        result = Call::Result.new(
          type: method.return_type,
          type_name: method.name,
          reference: false,
          pointer: 0,
          conversion: nil,
        )

        Call.new(
          origin: method,
          name: method.crystal_name,
          result: result,
          arguments: [myself],
          body: Body.new(@db),
        )
      end

      class Body < Call::Body
        def initialize(@db : TypeDatabase)
        end

        def to_code(call : Call, _platform : Graph::Platform) : String
          formatter = Crystal::Format.new(@db)
          myself = call.arguments.first

          %[def #{call.name}(#{formatter.argument_list(call.arguments)})\n] \
          %[end]
        end
      end
    end
  end
end
