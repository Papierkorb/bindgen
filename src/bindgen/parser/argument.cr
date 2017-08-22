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

        # `Argument` part
        hasDefault: Bool,
        name: String,
      )

      def initialize(@name, @baseName, @fullName, @isConst, @isReference, @isMove, @isBuiltin, @isVoid, @pointer, @kind = Type::Kind::Class, @hasDefault = false)
      end

      def initialize(@name, type : Type, @hasDefault = false)
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
      end

      def_equals_and_hash @baseName, @fullName, @isConst, @isReference, @isMove, @isBuiltin, @isVoid, @pointer, @hasDefault, @name

      # Does this argument have a default value?
      def has_default?
        @hasDefault
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
