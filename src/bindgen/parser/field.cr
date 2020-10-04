module Bindgen
  module Parser
    # A C++ struct/class field.
    class Field < Type
      include JSON::Serializable

      # Visibility of the field.
      getter access : AccessSpecifier

      # Name of the field.
      getter name : String

      # The size of this field, if it is a bitfield.
      @[JSON::Field(key: "bitField")]
      getter! bit_field : Int32

      delegate public?, private?, protected?, to: @access

      # Suitable name for Crystal code
      def crystal_name : String
        @name.underscore
      end
    end
  end
end
