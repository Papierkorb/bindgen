module Bindgen
  module Parser
    # Describes a class which is derived from another `Bindgen::Class`.
    class BaseClass
      include JSON::Serializable

      # Is this inheritance virtual?
      @[JSON::Field(key: "isVirtual")]
      getter? virtual : Bool

      # Does the `Bindgen::Class` derive its constructors from this class?
      @[JSON::Field(key: "inheritedConstructor")]
      getter? inherited_constructor : Bool

      # Fully qualified name of the base class.
      getter name : String

      # Visibility of the base class.
      getter access = Bindgen::Parser::AccessSpecifier::Public

      def initialize(@name, @access = AccessSpecifier::Public, @virtual = false, @inherited_constructor = false)
      end

      delegate public?, protected?, private?, to: @access
    end
  end
end
