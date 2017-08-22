module Bindgen
  module Parser
    # Describes a class which is derived from another `Bindgen::Class`.
    class BaseClass
      JSON.mapping(
        isVirtual: Bool,
        inheritedConstructor: Bool,
        name: String,
        access: AccessSpecifier,
      )

      def initialize(@name, @access = AccessSpecifier::Public, @isVirtual = false, @inheritedConstructor = false)
      end

      delegate public?, protected?, private?, to: @access

      # If this inheritance is virtual
      def virtual?
        @isVirtual
      end

      # If the `Bindgen::Class` derives its constructors from this class.
      def inherited_constructor?
        @inheritedConstructor
      end
    end
  end
end
