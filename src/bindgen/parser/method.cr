module Bindgen
  module Parser
    # Describes a method as found by the clang tool.
    class Method
      include JSON::Serializable

      # Collection of methods
      alias Collection = Array(Method)

      # Method types
      enum Type
        Constructor
        CopyConstructor
        Destructor
        MemberMethod
        MemberGetter
        MemberSetter
        StaticMethod
        StaticGetter
        StaticSetter
        Operator

        # Qt signal
        Signal

        # Is this one of the static method types?
        def static? : Bool
          static_method? || static_getter? || static_setter?
        end
      end

      # Type of the method.
      getter type : Method::Type

      # Name of the method.
      getter name : String

      # Visibility of the method.
      getter access : AccessSpecifier

      # Returns if the method is const-qualified:
      #   `std::string getName() const;`
      @[JSON::Field(key: "isConst")]
      getter? const : Bool

      # Is this a virtual function?
      @[JSON::Field(key: "isVirtual")]
      getter? virtual : Bool

      # Is this a pure virtual function?
      @[JSON::Field(key: "isPure")]
      getter? pure : Bool

      # Does this function use the C ABI?
      @[JSON::Field(key: "isExternC")]
      getter? extern_c : Bool

      # Fully qualified name of the class in which the method is defined.
      @[JSON::Field(key: "className")]
      getter class_name : String

      # Arguments of the method.
      property arguments : Array(Argument)

      # The index of the first argument with a default value, if any.
      @[JSON::Field(key: "firstDefaultArgument")]
      getter first_default_argument : Int32?

      # Return type of the method.
      @[JSON::Field(key: "returnType")]
      getter return_type : Parser::Type

      # Forces the wrapper to use the specified name.
      @[JSON::Field(ignore: true)]
      setter crystal_name : String?

      # The method this method is based on.  Used by `#variants` to indicate
      # the methods origin when splitting occurs.
      @[JSON::Field(ignore: true)]
      getter origin : Method?

      def initialize(
        @name, @class_name, @return_type, @arguments, @first_default_argument = nil,
        @access = AccessSpecifier::Public, @type = Type::MemberMethod,
        @const = false, @virtual = false, @pure = false, @extern_c = false,
        @origin = nil, @crystal_name = nil
      )
      end

      # Utility method to easily build a `Method` using a more Crystal-style
      # syntax.
      def self.build(
        name, return_type : Parser::Type, arguments : Array(Parser::Argument), class_name : String,
        type = Parser::Method::Type::MemberMethod, access = AccessSpecifier::Public,
        crystal_name = nil
      ) : self
        method = Parser::Method.new(
          type: type,
          access: access,
          name: name,
          const: false,
          class_name: class_name,
          first_default_argument: nil,
          return_type: return_type,
          arguments: arguments,
        )

        method.crystal_name = crystal_name if crystal_name
        method
      end

      delegate constructor?, copy_constructor?, member_method?, member_getter?,
        member_setter?, static?, static_method?, static_getter?, static_setter?,
        signal?, operator?, destructor?, to: @type
      delegate public?, protected?, private?, to: @access

      def_equals_and_hash @type, @name, @class_name, @access, @arguments,
        @first_default_argument, @return_type, @const, @virtual, @pure, @extern_c

      # Does this function take a variable amount of arguments?
      def variadic? : Bool
        !!@arguments.last?.try(&.variadic?)
      end

      # Is this a `Type::Constructor` or a `Type::CopyConstructor`?
      def any_constructor? : Bool
        @type.constructor? || @type.copy_constructor?
      end

      # Yields all variants of this method, going through an increasing level of
      # default arguments.  It will respect exposed default-values.
      #
      # A C++ method like `int foo(int a, int b = 1, std::string c = "foo")`
      # would yield two methods like:
      # * `int foo(int a, int b, std::string c)`
      # * `int foo(int a, int b = 1)`
      #
      # Note that only built-in types (These are: Integers, Floats and Booleans)
      # support an exposed default value.  For other types (Like `std::string`
      # in the example), no default value will be set.
      #
      # Also see `#find_variant_splits` for the algorithm.
      def variants
        first_default = @first_default_argument || @arguments.size

        find_variant_splits.each do |idx|
          # Adjust yielded Methods `@first_default_argument` to the correct value.
          first = first_default
          first = nil if first >= idx

          if idx == @arguments.size
            yield self
            next
          end

          args = @arguments[0...idx]
          if without_until = args.rindex { |arg| !arg.has_exposed_default? }
            args.map_with_index! do |arg, idx|
              if idx <= without_until
                arg.without_default
              else
                arg
              end
            end
          end

          variant = Method.new(
            type: @type,
            access: @access,
            name: @name,
            class_name: @class_name,
            arguments: args,
            first_default_argument: first,
            return_type: @return_type,
            const: @const,
            virtual: @virtual,
            pure: @pure,
            origin: self,
          )

          variant.crystal_name = @crystal_name
          yield variant
        end

        self
      end

      # Non-yielding version of `#variants`.
      def variants : Array(Method)
        list = [] of Method
        variants { |variant| list << variant }
        list
      end

      # Finds the indices in `@arguments` `#variants` should yield.
      private def find_variant_splits
        first_default = @first_default_argument
        return {@arguments.size} if first_default.nil?

        # If we're here, the method has default arguments.
        splits = [] of Int32
        seen_non_exposed = false

        # Split if the argument has a default value (In C++), but its default
        # value is *not* exposed to Crystal.
        @arguments.each_with_index do |arg, idx|
          next unless arg.has_default? # Skip leading non-defaults
          seen_non_exposed ||= !arg.has_exposed_default?

          # Split just before an argument with an non-exposed default.
          splits << idx if seen_non_exposed
        end

        # Add the variant of the whole method.
        splits << @arguments.size
        splits
      end

      # Returns a non-virtual copy of this method suitable for use in superclass
      # wrapper structs.  The bodies of such copies are expected to ignore
      # method overriding.
      def superclass_copy : Method
        Method.new(
          type: @type,
          name: "#{@name}_SUPER",
          access: @access,
          class_name: @class_name,
          arguments: @arguments,
          first_default_argument: @first_default_argument,
          return_type: @return_type,
          const: @const,
          virtual: false,
          pure: false,
          origin: self,
        )
      end

      # Try to deduce if this is a getter.
      def getter?(name = @name)
        @arguments.empty? && !@return_type.void? && /^get[_A-Z]/.match(name)
      end

      # Try to deduce if this is a setter.
      def setter?(name = @name)
        @arguments.size == 1 && @return_type.void? && /^set[_A-Z]/.match(name)
      end

      # Try to deduce if this is a getter for a boolean value.
      def question_getter?(name = @name)
        return unless @arguments.empty?
        return unless @return_type.builtin?
        return unless @return_type.full_name == "bool"

        /^(?:get|has|is)[_A-Z]/.match(name)
      end

      # Does this method have move semantics anywhere?
      def has_move_semantics? : Bool
        return true if @return_type.move?
        @arguments.any?(&.move?)
      end

      # Checks if the `#crystal_name` was set explicitly (`true`), or will be
      # generated (`false`).
      def explicit_crystal_name? : Bool
        !@crystal_name.nil?
      end

      # Turns the method name into something canonical to Crystal.  If a
      # explicit `#crystal_name` name is set, it'll be returned without furtehr
      # processing.  If *override* is not `nil`, it'll be used over `#name`.
      # Otherwise, the generated name will be based on `#name`.
      def crystal_name(override : String? = nil) : String
        if enforced_name = @crystal_name
          return enforced_name
        end

        name = (override || @name).underscore

        case @type
        when .operator?
          name[8..-1] # Remove `operator` prefix
        when .signal?
          name # Don't butcher signal names
        when .member_method?, .static_method?
          if question_getter?(name)
            if name.starts_with?("is_")
              name[3..-1] + "?" # Remove `is_` prefix
            elsif name.starts_with?("get_")
              name[4..-1] + "?" # Remove `get_` prefix
            else
              name + "?" # Keep `has_` prefix!
            end
          elsif getter?(name)
            name[4..-1] # Remove `get_` prefix
          elsif setter?(name)
            name[4..-1] + "=" # Remove `set_` prefix and add `=` suffix
          else
            name # Normal method
          end
        when .member_getter?, .static_getter?
          name
        when .member_setter?, .static_setter?
          name + "="
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

      # Checks if this method is equal to *other*, except for the
      # const-qualification.
      def equals_except_const?(other : Method) : Bool
        # Note: Don't look at the return type for this, as it'll likely be
        # `const` itself too for the `const` method version.
        {% for i in %i[type name class_name virtual pure] %}
          return false if @{{ i.id }} != other.@{{ i.id }}
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
        {% for i in %i[type name virtual const return_type] %}
          return false if @{{ i.id }} != other.@{{ i.id }}
        {% end %}

        # Check arguments only by their type, NOT their name.
        return false if other.arguments.size != @arguments.size
        @arguments.zip(other.arguments) do |l, r|
          return false unless l.type_equals?(r)
        end

        true
      end

      # The return type of this method
      def return_type : Parser::Type
        if any_constructor? && @return_type.base_name.empty?
          Parser::Type.new(
            const: false,
            reference: false,
            move: false,
            void: false,
            builtin: false,
            base_name: @class_name,
            full_name: "#{@class_name}*",
            pointer: 1,
          )
        else
          @return_type
        end
      end

      # Returns if this method needs a class instance to be called.
      def needs_instance?
        !(any_constructor? || static?)
      end

      # Returns if this method returns something, or not
      def has_result?
        !@return_type.void?
      end

      # Is this method filtered out?
      #
      # TODO: Can we move this into `Processor::FilterMethods`?
      def filtered?(db : TypeDatabase) : Bool
        return true if private?
        return true if db[@return_type]?.try(&.ignore?)
        return true if @arguments.any? { |arg| db[arg]?.try(&.ignore?) }

        if list = db[@class_name]?.try(&.ignore_methods)
          return true if list.includes?(@name)
        end

        # Check that all arguments, which pass in explicit by-value, either take
        # the value directly, or a const-reference to it.
        pass_by_value_violation = @arguments.any? do |arg|
          pass_by = db.try_or(arg, TypeDatabase::PassBy::Original, &.pass_by)
          next false unless pass_by.value?           # Is it explicitly by-value?
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
        class_name = Util.mangle_type_name(@class_name)
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
        when .constructor?      then "#{name}_CONSTRUCT"
        when .copy_constructor? then "#{name}_COPY"
        when .member_getter?    then "#{name}_GETTER"
        when .member_setter?    then "#{name}_SETTER"
        when .operator?         then operator_name
        when .static_method?    then "#{name}_STATIC"
        when .static_getter?    then "#{name}_STATIC_GETTER"
        when .static_setter?    then "#{name}_STATIC_SETTER"
        when .destructor?       then "#{name}_DESTROY"
        else                         name
        end
      end

      # Name of the operator method in C++ and Crystal bindings.
      private def operator_name
        case @name
        when "operator<"  then "OPERATOR_lt"
        when "operator>"  then "OPERATOR_gt"
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
        prefix = "#{@class_name}::" if needs_instance?
        suffix = "const" if const?
        args = @arguments.map(&.full_name)
        "#{@return_type.full_name}(#{prefix}*#{name})(#{args.join(", ")})#{suffix}"
      end

      # Merges this and the *other* method with regards to default values and
      # type deductions.  Expects that this and *other* methods point at the
      # same method, but in different classes in the inheritance chain.
      #
      # Keeps the class name, access, constness, virtuality and type of this
      # method.
      def merge(other : Method) : Method
        args = [] of Argument

        @arguments.zip(other.arguments) do |l, r|
          args << l.merge(r)
        end

        result = Method.new(
          type: @type,
          access: @access,
          name: @name,
          class_name: @class_name,
          arguments: args,
          first_default_argument: @first_default_argument,
          return_type: @return_type,
          const: @const,
          virtual: @virtual,
          pure: @pure && other.pure?,
        )

        result.crystal_name = @crystal_name
        result
      end
    end
  end
end
