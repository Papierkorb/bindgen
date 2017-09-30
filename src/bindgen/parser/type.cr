module Bindgen
  module Parser
    # Stores information about a specific C++ type.
    class Type
      # Name of the `CrystalProc` C++ and Crystal type.  This type is a template
      # type in C++, and a `struct` in Crystal.
      CRYSTAL_PROC = "CrystalProc"

      # Type kinds.  Currently not used by the clang tool.
      enum Kind
        Class
        Struct
        Enum
        Function
      end

      # ATTENTION: Changes here have to be kept in sync with `Parser::Argument`s mapping!!
      # Also make sure to update other methods in here and in `Argument` as required!
      JSON.mapping(
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
      )

      # `Void` type
      VOID = new(
        isConst: false,
        isMove: false,
        isReference: false,
        isBuiltin: true,
        isVoid: true,
        pointer: 0,
        baseName: "void",
        fullName: "void",
        template: nil,
        nilable: false,
      )

      # Returns a `Type` of a C++ built-in type *cpp_name*.
      def self.builtin_type(cpp_name : String, pointer = 0, reference = false)
        new(
          isConst: false,
          isMove: false,
          isReference: reference,
          isBuiltin: true,
          isVoid: (cpp_name == "void"),
          pointer: pointer,
          baseName: cpp_name,
          fullName: cpp_name,
          template: nil,
          nilable: false,
        )
      end

      # Parser for qualified C++ type-names.  It's really stupid though.
      def self.parse(type_name : String, pointer_depth = 0)
        name = type_name.strip # Clean the name
        reference = false
        const = false

        # Is it const-qualified?
        if name.starts_with?("const ")
          const = true
          name = name[6..-1] # Remove `const `
        end

        # Is it a reference?
        if name.ends_with?('&')
          reference = true
          pointer_depth += 1
          name = name[0..-2] # Remove ampersand
        end

        # Is it a pointer?
        while name.ends_with?('*')
          pointer_depth += 1
          name = name[0..-2] # Remove star
        end

        new( # Build the `Type`
          isConst: const,
          isMove: false,
          isReference: reference,
          isBuiltin: false, # Oh well
          isVoid: (name == "void"),
          pointer: pointer_depth,
          baseName: name.strip,
          fullName: type_name,
          template: nil,
          nilable: false,
        )
      end

      # Creates a `Type` describing a Crystal `Proc` type, which returns a
      # *return_type* using *arguments*.
      #
      # The generated type will use `CrystalProc` as base type.
      def self.proc(return_type : Type, arguments : Enumerable(Type))
        base = "CrystalProc"

        template_args = [ return_type ] + arguments.to_a
        template = Template.new(
          fullName: base,
          baseName: base,
          arguments: template_args,
        )

        new( # Build the `Type`
          kind: Kind::Function,
          isConst: false,
          isMove: false,
          isReference: false,
          isBuiltin: false,
          isVoid: false,
          pointer: 0,
          baseName: base,
          fullName: base,
          template: template,
          nilable: false,
        )
      end

      def_equals_and_hash @baseName, @fullName, @isConst, @isReference, @isMove, @isBuiltin, @isVoid, @pointer, @kind, @nilable

      def initialize(@baseName, @fullName, @isConst, @isReference, @isMove, @isBuiltin, @isVoid, @pointer, @kind = Kind::Class, @template = nil, @nilable = false)
      end

      # Is this type nilable?  For compatibility with `Argument`.
      getter? nilable : Bool

      # Checks if this type equals the *other* type, except for nil-ability.
      def equals_except_nil?(other : Type)
        {% for i in %i[ baseName fullName isConst isReference isMove isBuiltin isVoid pointer kind ] %}
        return false if @{{ i.id }} != other.{{ i.id }}
        {% end %}

        true
      end

      # Is this type constant?
      def const?
        @isConst
      end

      # Does the type use move-semantics?
      def move?
        @isMove
      end

      # Is this a C++ reference type?
      def reference?
        @isReference
      end

      # Is this type a C++ built-in type?
      def builtin?
        @isBuiltin
      end

      # Is it C++ `void`?
      def void?
        @isVoid
      end

      # Unqualified base name for easier mapping to Crystal.
      #
      # E.g., the base name of `const QWidget *&` is `QWidget`.
      def base_name
        @baseName
      end

      # Fully qualified, full name, for the C++ bindings.
      def full_name
        @fullName
      end

      # The mangled type name for C++ bindings.
      def mangled_name
        if @kind.function? && (templ = @template)
          Util.mangle_type_name(@fullName) + "_" + templ.mangled_name
        else
          Util.mangle_type_name @fullName
        end
      end
    end
  end
end
