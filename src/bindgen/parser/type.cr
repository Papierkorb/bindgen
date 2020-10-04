module Bindgen
  module Parser
    # Stores information about a specific C++ type.
    class Type
      include JSON::Serializable

      # Name of the `CrystalProc` C++ and Crystal type.  This type is a template
      # type in C++, and a `struct` in Crystal.
      CRYSTAL_PROC = "CrystalProc"

      # Type kinds.  Currently not used by the clang tool.
      # TODO: use `Parser::TypeKind` instead
      enum Kind
        Class
        Struct
        Enum
        Function
      end

      # ATTENTION: Make sure to update other methods in here and in `Argument`
      # as required!

      # Type kind.
      getter kind = Bindgen::Parser::Type::Kind::Class

      # Is this type constant?
      @[JSON::Field(key: "isConst")]
      getter? const : Bool

      # Is this a C++ rvalue reference type?
      @[JSON::Field(key: "isMove")]
      getter? move : Bool

      # Is this a C++ lvalue reference type?
      @[JSON::Field(key: "isReference")]
      getter? reference : Bool

      # Is this type a C++ built-in type?
      @[JSON::Field(key: "isBuiltin")]
      getter? builtin : Bool

      # Is it C++ `void`?  Note that `void *` is also void.
      # See also `#pure_void?`
      @[JSON::Field(key: "isVoid")]
      getter? void : Bool

      # Total number of indirections from pointers and lvalue references.
      getter pointer : Int32

      # Unqualified base name for easier mapping to Crystal.
      #
      # E.g., the base name of `const QWidget *&` is `QWidget`.
      @[JSON::Field(key: "baseName")]
      getter base_name : String

      # Fully qualified, full name, for the C++ bindings.
      @[JSON::Field(key: "fullName")]
      getter full_name : String

      # Is this type nilable?  For compatibility with `Argument`.
      @[JSON::Field(key: "acceptsNull")]
      getter? nilable = false

      # Template information, if this type is a template type.
      getter template : Template?

      # `Void` type
      VOID = new(
        const: false,
        move: false,
        reference: false,
        builtin: true,
        void: true,
        pointer: 0,
        base_name: "void",
        full_name: "void",
        template: nil,
        nilable: false,
      )

      # Empty type, as is returned by the parser for constructors.  Only valid
      # as a return type of a constructor method.
      EMPTY = new(
        const: false,
        move: false,
        reference: false,
        builtin: true,
        void: false,
        pointer: 0,
        base_name: "",
        full_name: "",
        template: nil,
        nilable: false,
      )

      # Returns a `Type` of a C++ built-in type *cpp_name*.
      def self.builtin_type(cpp_name : String, pointer = 0, reference = false)
        new(
          const: false,
          move: false,
          reference: reference,
          builtin: true,
          void: (cpp_name == "void"),
          pointer: pointer,
          base_name: cpp_name,
          full_name: cpp_name,
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
          const: const,
          move: false,
          reference: reference,
          builtin: false, # Oh well
          void: (name == "void"),
          pointer: pointer_depth,
          base_name: name.strip,
          full_name: type_name,
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

        template_args = [return_type] + arguments.to_a
        template = Template.new(
          full_name: base,
          base_name: base,
          arguments: template_args,
        )

        new( # Build the `Type`
          kind: Kind::Function,
          const: false,
          move: false,
          reference: false,
          builtin: false,
          void: false,
          pointer: 0,
          base_name: base,
          full_name: base,
          template: template,
          nilable: false,
        )
      end

      # Decays the type.  This means that a single "layer" of information is
      # removed from this type.  Each rule is tried in the following order.
      # The first winning rule returns a new type.
      #
      # 1. If `#const?`, remove const (`const int &` -> `int &`)
      # 2. If `#reference?`, pointer-ize (`int &` -> `int *`)
      # 3. If `#pointer > 0`, remove one (`int *` -> `int`)
      # 4. Else, it's the base-type already.  Return `nil`.
      def decayed : Type?
        is_const = @const
        is_ref = @reference
        ptr = @pointer

        if is_const # 1.
          is_const = false
        elsif is_ref # 2.
          is_ref = false
        elsif ptr > 0 # 3.
          ptr -= 1
        else # 4.
          return nil
        end

        typer = Cpp::Typename.new
        type_ptr = ptr
        type_ptr -= 1 if is_ref

        Type.new(
          kind: @kind,
          const: is_const,
          reference: is_ref,
          move: false,
          builtin: @builtin,
          void: @void,
          pointer: ptr,
          base_name: @base_name,
          full_name: typer.full(@base_name, is_const, type_ptr, is_ref),
          template: @template,
          nilable: @nilable,
        )
      end

      # If the type is a pointer and not a reference, returns a copy of this
      # type that is nilable, otherwise returns `nil`.
      def make_pointer_nilable : Type?
        if @pointer > 0 && !@reference && !@move
          Type.new(
            kind: @kind,
            const: @const,
            reference: false,
            move: false,
            builtin: @builtin,
            void: @void,
            pointer: @pointer,
            base_name: @base_name,
            full_name: @full_name,
            template: @template,
            nilable: true,
          )
        end
      end

      def_equals_and_hash @base_name, @full_name, @const, @reference, @move,
        @builtin, @void, @pointer, @kind, @nilable

      def initialize(
        @base_name, @full_name, @const, @reference, @pointer, @move = false,
        @builtin = false, @void = false, @kind = Kind::Class, @template = nil,
        @nilable = false
      )
      end

      # Checks if this type equals the *other* type, except for nil-ability.
      def equals_except_nil?(other : Type)
        {% for i in %i[base_name full_name const reference move builtin void pointer kind template] %}
          return false if @{{ i.id }} != other.@{{ i.id }}
        {% end %}

        true
      end

      # Returns `true` if this type is `void`, and nothing else.
      def pure_void?
        @void && @pointer == 0
      end

      # The mangled type name for C++ bindings.
      def mangled_name
        if @kind.function? && (templ = @template)
          Util.mangle_type_name(@full_name) + "_" + templ.mangled_name
        else
          Util.mangle_type_name @full_name
        end
      end
    end
  end
end
