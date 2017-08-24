module Bindgen
  module Parser
    # A C++ struct/class field.
    class Field < Type
      JSON.mapping(
        # Type part
        kind: {
          type: Kind,
          default: Kind::Class,
        },
        isConst: Bool,
        isMove: Bool,
        isReference: Bool,
        isBuiltin: Bool,
        isVoid: Bool,
        pointer: Int32,
        baseName: String,
        fullName: String,
        nilable: {
          type: Bool,
          key: "acceptsNull",
          default: false,
        },
        template: {
          type: Template,
          nilable: true,
        },

        # Field part
        access: AccessSpecifier,
        name: String,
        bitField: Int32?,
      )

      delegate public?, private?, protected?, to: @access

      # Returns the bit-size of this bitfield.
      def bit_field : Int32
        @bitField.not_nil!
      end

      # Returns the size of this bitfield, if it is a bitfield.
      def bit_field? : Int32?
        @bitField
      end

      # Suitable name for Crystal code
      def crystal_name : String
        @name.underscore
      end
    end
  end
end
