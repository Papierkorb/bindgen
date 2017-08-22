module Bindgen
  module Parser
    # Describes a method as found by the clang tool.
    class Method
      # Method types
      enum Type
        Constructor
        CopyConstructor
        Destructor
        MemberMethod
        StaticMethod
        Operator

        # Qt signal
        Signal
      end

      JSON.mapping(
        type: Method::Type,
        name: String,
        access: AccessSpecifier,
        isConst: Bool,
        isVirtual: Bool,
        isPure: Bool,
        className: String,
        arguments: Array(Argument),
        firstDefaultArgument: Int32?,
        returnType: Parser::Type,
      )

      # For hard-wiring a methods final wrapper name.
      @crystal_name : String? = nil

      def initialize(@type, @access, @name, @className, @arguments, @firstDefaultArgument, @returnType, @isConst = false, @isVirtual = false, @isPure = false)
      end

      delegate constructor?, copy_constructor?, member_method?, static_method?, signal?, operator?, destructor?, to: @type
      delegate public?, protected?, private?, to: @access

      def_equals_and_hash @type, @name, @className, @access, @arguments, @firstDefaultArgument, @returnType, @isConst, @isVirtual, @isPure

      # Is this a virtual function?
      def virtual? : Bool
        @isVirtual
      end

      # Is this a pure virtual function?
      def pure? : Bool
        @isPure
      end

      # Is this a `Type::Constructor` or a `Type::CopyConstructor`?
      def any_constructor? : Bool
        @type.constructor? || @type.copy_constructor?
      end

      # Yields all variants of this method, going through an increasing level of default arguments.
      #
      # A C++ method like `int foo(int a, int b = 1, int c = 2)` would yield three methods like:
      # * `int foo(int a, int b, int c)`
      # * `int foo(int a, int b)`
      # * `int foo(int a)`
      def variants
        return self if private?

        first_def = @firstDefaultArgument || @arguments.size
        (first_def..@arguments.size).each do |idx|
          first = first_def
          first = nil if first >= idx

          args = @arguments[0...idx]
          variant = Method.new(
            type: @type,
            access: @access,
            name: @name,
            className: @className,
            arguments: args,
            firstDefaultArgument: first,
            returnType: @returnType,
            isConst: @isConst,
            isVirtual: @isVirtual,
            isPure: @isPure
          )

          variant.crystal_name = @crystal_name
          yield variant
        end

        self
      end

      # Non-yielding version of `#variant`.
      def variants : Array(Method)
        list = [ ] of Method
        variants{|variant| list << variant}
        list
      end

      # Try to deduce if this is a getter.
      def getter?
        @arguments.empty? && !@returnType.void? && /^get[_A-Z]/.match(@name)
      end

      # Try to deduce if this is a setter.
      def setter?
        @arguments.size == 1 && @returnType.void? && /^set[_A-Z]/.match(@name)
      end

      # Try to deduce if this is a getter for a boolean value.
      def question_getter?
        return unless @arguments.empty?
        return unless @returnType.builtin?
        return unless @returnType.full_name == "bool"

        /^(?:get|has|is)[_A-Z]/.match(@name)
      end

      # Does this method have move semantics anywhere?
      def has_move_semantics? : Bool
        return true if @returnType.move?
        @arguments.any?(&.move?)
      end

      # Forces the wrapper to use the specified name
      setter crystal_name : String?

      # Checks if the `#crystal_name` was set explicitly (`true`), or will be
      # generated (`false`).
      def explicit_crystal_name? : Bool
        !@crystal_name.nil?
      end

      # Turns the method name into something canonical to Crystal
      def crystal_name : String
        if enforced_name = @crystal_name
          return enforced_name
        end

        name = @name.underscore

        case self
        when .operator?
          name[8..-1] # Remove `operator` prefix
        when .signal?
          name # Don't butcher signal names
        when .member_method?, .static_method?
          if question_getter?
            if name.starts_with?("is_")
              name[3..-1] + "?" # Remove `is_` prefix
            elsif name.starts_with?("get_")
              name[4..-1] + "?" # Remove `get_` prefix
            else
              name + "?" # Keep `has_` prefix!
            end
          elsif getter?
            name[4..-1] # Remove `get_` prefix
          elsif setter?
            name[4..-1] + "=" # Remove `set_` prefix and add `=` suffix
          else
            name # Normal method
          end
        when .constructor?
          "initialize"
        when .copy_constructor?
          "clone"
        when .destructor?
          "finalize"
        else
          raise "BUG: No #crystal_name implementation for type #{@type}"
        end
      end

      # Returns the binding name of the signal-connect method.
      def connect_name
        "#{name}_CONNECT"
      end

      # Returns if the method is const-qualified:
      #   `std::string getName() const;`
      def const?
        @isConst
      end

      # Checks if this method is equal to *other*, except for the
      # const-qualification.
      def equals_except_const?(other : Method) : Bool
        # Note: Don't look at the return type for this, as it'll likely be
        # `const` itself too for the `const` method version.
        {% for i in %i[ type name className isVirtual isPure ] %}
        return false if @{{ i.id }} != other.{{ i.id }}
        {% end %}

        # Check arguments only by their type, NOT their name.
        return false if other.arguments.size != @arguments.size
        @arguments.zip(other.arguments) do |l, r|
          return false unless l.type_equals?(r)
        end

        true
      end

      # Checks if this method is equl to *other*, as is suitable to determine
      # if they're the same for C++ virtual methods between parent- and
      # sub-classes.
      def equals_virtually?(other : Method) : Bool
        # Don't check if they're both pure or not: One may not in an abstract
        # base.
        {% for i in %i[ type name isVirtual isConst returnType ] %}
        return false if @{{ i.id }} != other.{{ i.id }}
        {% end %}

        # Check arguments only by their type, NOT their name.
        return false if other.arguments.size != @arguments.size
        @arguments.zip(other.arguments) do |l, r|
          return false unless l.type_equals?(r)
        end

        true
      end

      # Returns the index of the first argument with a default value, if any.
      def first_default_argument
        @firstDefaultArgument
      end

      # The return type of this method
      def return_type : Parser::Type
        if any_constructor?
          Parser::Type.new(
            isConst: false,
            isReference: false,
            isMove: false,
            isVoid: false,
            isBuiltin: false,
            baseName: @className,
            fullName: "#{@className}*",
            pointer: 1,
          )
        else
          @returnType
        end
      end

      # Returns if this method needs a class instance to be called.
      def needs_instance?
        !(any_constructor? || static_method?)
      end

      # Returns if this method returns something, or not
      def has_result?
        !@returnType.void?
      end

      # Name of the class this method is in
      def class_name
        @className
      end

      # Is this method filtered out?
      def filtered?(db : TypeDatabase) : Bool
        return true if db[@returnType]?.try(&.ignore?)
        return true if @arguments.any?{|arg| db[arg]?.try(&.ignore?)}

        if list = db[@className]?.try(&.ignore_methods)
          return true if list.includes?(@name)
        end

        # Check that all arguments, which pass in explicit by-value, either take
        # the value directly, or a const-reference to it.
        pass_by_value_violation = @arguments.any? do |arg|
          pass_by = db.try_or(arg, TypeDatabase::PassBy::Original, &.pass_by)
          next false unless pass_by.value? # Is it explicitly by-value?
          next true if arg.reference? && !arg.const? # Not const-ref - Violation!
          pointer_depth = arg.pointer
          pointer_depth -= 1 if arg.reference?

          pointer_depth > 0 # It's by-pointer - Violation!
        end

        return true if pass_by_value_violation

        false # This method is fine.
      end

      # Mangled name for the C++ wrapper method name
      def mangled_name
        class_name = Util.mangle_type_name(@className)
        "bg_#{class_name}_#{binding_method_name}_#{binding_arguments_name}"
      end

      # Mangles the list of argument types into a flat string.
      def binding_arguments_name
        @arguments.map(&.mangled_name).join("_")
      end

      # Name of the method in C++ and Crystal bindings.
      def binding_method_name
        name = Util.mangle_type_name(@name)

        case self
        when .constructor? then "CONSTRUCT"
        when .copy_constructor? then "COPY"
        when .operator? then operator_name
        when .static_method? then "#{name}_STATIC"
        when .destructor? then "DESTROY"
        else name
        end
      end

      # Name of the operator method in C++ and Crystal bindings.
      private def operator_name
        case @name
        when "operator<" then "OPERATOR_lt"
        when "operator>" then "OPERATOR_gt"
        when "operator<=" then "OPERATOR_le"
        when "operator>=" then "OPERATOR_ge"
        when "operator==" then "OPERATOR_eq"
        when "operator!=" then "OPERATOR_ne"
        else
          raise "Unexpected operator #{@name.inspect}"
        end
      end

      # Generates a C++ function pointer type matching this methods prototype.
      def function_pointer(name : String? = nil) : String
        prefix = "#{@className}::" if needs_instance?
        suffix = "const" if const?
        args = @arguments.map(&.full_name)
        "#{@returnType.full_name}(#{prefix}*#{name})(#{args.join(", ")})#{suffix}"
      end
    end
  end
end
