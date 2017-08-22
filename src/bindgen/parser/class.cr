module Bindgen
  module Parser
    # Describes a C++ `class` or `struct`.
    class Class
      # Collection of classes.
      alias Collection = Hash(String, Class)

      JSON.mapping(
        isClass: Bool,
        hasDefaultConstructor: Bool,
        hasCopyConstructor: Bool,
        isAbstract: Bool,
        name: String,
        byteSize: Int32,
        bases: Array(BaseClass),
        fields: Array(Field),
        methods: Array(Method),
      )

      def initialize(@name, @byteSize = 0, @hasDefaultConstructor = false, @hasCopyConstructor = false, @isClass = true, @isAbstract = false)
        @bases = Array(BaseClass).new
        @fields = Array(Field).new
        @methods = Array(Method).new
      end

      # Is this a `class`?  Opposite of `#struct?`.
      def class?
        @isClass
      end

      # Is this a `struct`?  Opposite of `#class?`.
      def struct?
        !@isClass
      end

      # Does the type have a default, argument-less constructor?
      def has_default_constructor?
        @hasDefaultConstructor
      end

      # Is the type copy-constructable?
      def has_copy_constructor?
        @hasCopyConstructor
      end

      # Size of an instance of the class in memory.
      def byte_size : Int32
        @byteSize
      end

      # Is this class abstract?
      def abstract?
        @isAbstract
      end

      # Does this class have any virtual methods?
      def has_virtual_methods?
        @methods.any?(&.virtual?)
      end

      # The full binding function name of the destructor.
      def destructor_name : String
        "bg_#{binding_name}_DESTROY"
      end

      # The name of the class as part of binding methods.
      def binding_name : String
        Util.mangle_type_name(@name)
      end

      # Constructs a method destroying an instance of this class.
      def destructor_method : Method
        Parser::Method.new(
          type: Method::Type::Destructor,
          name: "DESTROY",
          access: AccessSpecifier::Public,
          isConst: false,
          isVirtual: true, # Hopefully.
          isPure: false,
          className: @name,
          arguments: [ ] of Argument,
          firstDefaultArgument: nil,
          returnType: Type::VOID,
        )
      end

      # The full binding function name of a `_AS_` function, used to cast
      # a class instance into an instance of another type in a
      # multiple-inheritance scenario.
      def converter_name(target : Class | String) : String
        target = target.name if target.is_a?(Class)
        target = Util.mangle_type_name(target)
        "bg_#{binding_name}_AS_#{target}"
      end

      # List of all wrappable-methods.  This includes all `Method#variants`.
      # Methods which use `Method#move_semantics?` on any type are explicitly
      # removed.
      getter wrap_methods : Array(Method) do
        list = [ ] of Method

        # Collect all method variants
        @methods.each do |method|
          method.variants do |m|
            next if m.operator? # TODO: Support Operators!
            next if m.copy_constructor? # TODO: Support copy constructors!
            next if m.has_move_semantics? # Move semantics are hard to wrap.

            # Don't try to wrap copy-constructors in an abstract class.
            next if @isAbstract && method.copy_constructor?

            # Okay!
            list << m
          end
        end

        # And make sure there are no duplicates.
        Util.uniq_by(list){|a, b| a.equals_except_const?(b) || a.equals_virtually?(b)}
      end

      # Returns a `Type` referencing this class.
      def as_type(pointer = 1, reference = false, const = false) : Type
        full_name = name
        full_name = "const #{name}" if const
        full_name += "*" * pointer if pointer > 0
        full_name += "&" if reference
        pointer += 1 if reference

        Type.new(
          isConst: const,
          isReference: reference,
          isMove: false,
          isVoid: false,
          isBuiltin: false,
          baseName: name,
          fullName: full_name,
          pointer: pointer,
        )
      end
    end
  end
end
