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
        isDestructible: Bool,
        name: String,
        byteSize: Int32,
        bases: Array(BaseClass),
        fields: Array(Field),
        methods: Array(Method),
      )

      def initialize(@name, @byteSize = 0, @hasDefaultConstructor = false, @hasCopyConstructor = false, @isClass = true, @isAbstract = false, @isDestructible = true, @bases = [ ] of BaseClass, @fields = [ ] of Field, @methods = [ ] of Method)
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

      # Is this class publicly destructible?
      def destructible?
        @isDestructible
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

      # List of all wrappable-methods.  This includes all `Method#variants`.
      # Methods which use `Method#move_semantics?` on any type are explicitly
      # removed.
      #
      # Note: This is a memoized getter.  Thus it's cheap to call it multiple
      # times.
      getter wrap_methods : Array(Method) do
        list = [ ] of Method

        # Collect all method variants
        each_wrappable_method do |method|
          method.variants{|m| list << m}
        end

        # And make sure there are no duplicates.
        Util.uniq_by(list){|a, b| a.equals_except_const?(b) || a.equals_virtually?(b)}
      end

      # Yields each wrappable method without any further processing.
      #
      # **Note**: This method hard-codes which methods to ignore.  If you're
      # wondering why a method doesn't even reach the graph in the first place,
      # look in here.
      def each_wrappable_method
        @methods.each do |method|
          next if method.private?
          next if method.operator? # TODO: Support Operators!
          next if method.copy_constructor? # TODO: Support copy constructors!
          next if method.has_move_semantics? # Move semantics are hard to wrap.

          # Don't try to wrap copy-constructors in an abstract class.
          next if @isAbstract && method.copy_constructor?

          yield method
        end
      end

      # Non-yielding version of `#each_wrappable_method`
      def wrappable_methods
        list = [ ] of Method
        each_wrappable_method{|m| list << m}
        list
      end

      # Assumes that *method* exists in a class inheriting from this class.
      # Tries to find a method in this class which is overriden by *method*.
      def find_parent_method(method : Method) : Method?
        wrap_methods.find do |m|
          next if method.arguments.size != m.arguments.size
          next if method.name != m.name # Name check
          next unless method.return_type.equals_except_nil?(m.return_type)

          # Check all arguments for type-equality.
          hit_count = 0
          method.arguments.zip(m.arguments) do |l, r|
            break unless l.equals_except_nil?(r)
            hit_count += 1
          end

          hit_count == method.arguments.size
        end
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
