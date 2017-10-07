require "./type"

module Bindgen
  module Parser
    # Describes a method argument.
    class Argument < Type
      JSON.mapping(
        # `Type` part
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

        # `Argument` part
        hasDefault: Bool,
        name: String,
        value: {
          type: DefaultValueTypes,
          nilable: true,
          converter: ValueConverter,
        },
      )

      def initialize(@name, @baseName, @fullName, @isConst, @isReference, @isMove, @isBuiltin, @isVoid, @pointer, @kind = Type::Kind::Class, @hasDefault = false, @value = nil, @nilable = false)
      end

      def initialize(@name, type : Type, @hasDefault = false, @value = nil)
        @baseName = type.baseName
        @fullName = type.fullName
        @isConst = type.isConst
        @isReference = type.isReference
        @isMove = type.isMove
        @isBuiltin = type.isBuiltin
        @isVoid = type.isVoid
        @pointer = type.pointer
        @kind = type.kind
        @template = type.template
        @nilable = type.nilable
      end

      def_equals_and_hash @baseName, @fullName, @isConst, @isReference, @isMove, @isBuiltin, @isVoid, @pointer, @hasDefault, @name, @value, @nilable

      # Does this argument have a default value?
      def has_default?
        @hasDefault
      end

      # Does this argument have an exposed default value?
      def has_exposed_default?
        @hasDefault && @value != nil
      end

      # If this is a pointer-type, does it default to `nullptr` in C++?
      def defaults_to_nil? : Bool
        @pointer > 0 && value == true
      end

      # Assume that if the argument defaults to `nullptr`, that it is nilable.
      def nilable? : Bool
        defaults_to_nil? || super
      end

      # Returns a copy of this argument without a default value.
      def without_default : Argument
        self.class.new(
          name: @name,
          baseName: @baseName,
          fullName: @fullName,
          isConst: @isConst,
          isReference: @isReference,
          isMove: @isMove,
          isBuiltin: @isBuiltin,
          isVoid: @isVoid,
          pointer: @pointer,
          kind: @kind,
          hasDefault: false,
          value: nil,
          nilable: nilable?,
        )
      end

      # Merges this argument with *other*.  Only merges defaultness, its value
      # and nil-ability.  For the value, this argument takes precedence over
      # *other*.
      def merge(other : Argument)
        self.class.new(
          name: @name,
          baseName: @baseName,
          fullName: @fullName,
          isConst: @isConst,
          isReference: @isReference,
          isMove: @isMove,
          isBuiltin: @isBuiltin,
          isVoid: @isVoid,
          pointer: @pointer,
          kind: @kind,
          hasDefault: @hasDefault || other.has_default?,
          value: @value || other.value,
          nilable: nilable? || other.nilable?,
        )
      end

      # Checks if the type-part of this equals the type-part of *other*.
      def type_equals?(other : Type)
        {% for i in %i[ baseName fullName isConst isReference isMove isBuiltin isVoid pointer template ] %}
          return false if @{{ i.id }} != other.{{ i.id }}
        {% end %}

        true
      end
    end
  end
end
