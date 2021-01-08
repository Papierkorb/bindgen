module Bindgen
  module Parser
    # A C++ struct/class field.
    class Field < Type
      include JSON::Serializable

      # Visibility of the field.
      getter access : AccessSpecifier

      # Name of the field.
      getter name : String

      # Is this field a static data member?
      @[JSON::Field(key: "isStatic")]
      getter? static : Bool

      # The size of this field, if it is a bitfield.
      @[JSON::Field(key: "bitField")]
      getter! bit_field : Int32

      # Does this field have a default value?
      @[JSON::Field(key: "hasDefault")]
      getter? has_default : Bool

      # Default value for this field, if an initializer literal is found.
      @[JSON::Field(converter: Bindgen::Parser::ValueConverter)]
      getter value : DefaultValueTypes?

      delegate public?, private?, protected?, to: @access

      # Suitable name for Crystal code
      def crystal_name : String
        @name.underscore
      end
    end
  end
end
