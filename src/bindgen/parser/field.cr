module Bindgen
  module Parser
    # A C++ struct/class field.
    class Field < Type
      include JSON::Serializable

      property access : AccessSpecifier
      property name : String
      property bitField : Int32?

      def initialize(@kind, @isConst, @isMove, @isReference, @isBuiltin, @isVoid, @pointer,
                     @baseName, @fullName, @nilable, @template, @access, @name, @bitField)
      end

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
