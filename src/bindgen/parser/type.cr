module Bindgen
  module Parser
    # Stores information about a specific C++ type.
    class Type
      # Type kinds.  Currently not used by the clang tool.
      enum Kind
        Class
        Struct
        Enum
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
      )

      # Returns a `Type` of a C++ built-in type *cpp_name*.
      def self.builtin_type(cpp_name : String, pointer = 0, reference = false)
        new(
          isConst: false,
          isMove: false,
          isReference: reference,
          isBuiltin: true,
          isVoid: false,
          pointer: pointer,
          baseName: cpp_name,
          fullName: cpp_name,
          template: nil,
        )
      end

      # Parser for qualified C++ type-names.  It's really stupid though.
      def self.parse(type_name : String)
        name = type_name.strip # Clean the name
        reference = false
        pointer_depth = 0
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
        )
      end

      def_equals_and_hash @baseName, @fullName, @isConst, @isReference, @isMove, @isBuiltin, @isVoid, @pointer, @kind

      def initialize(@baseName, @fullName, @isConst, @isReference, @isMove, @isBuiltin, @isVoid, @pointer, @kind = Kind::Class, @template = nil)
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
        Util.mangle_type_name @fullName
      end
    end
  end
end
