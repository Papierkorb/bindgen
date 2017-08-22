module Bindgen
  # Base class of code generators.  Mostly a host of useful functionality for
  # multiple other generators.
  abstract class Generator
    # Type of the result of a Qt-sinal connect call.
    CONNECTION_HANDLE_TYPE = Parser::Type.new(
      isConst: false,
      isMove: false,
      isReference: false,
      isBuiltin: false,
      isVoid: false,
      pointer: 0,
      baseName: "QMetaObject::Connection",
      fullName: "QMetaObject::Connection",
    )

    # Name of the "standard" built-in integer C++ type
    CPP_INTEGER_TYPE = "int"

    # Helper adding *pointer_depth* count stars after the *type_name*.
    protected def with_pointer(type_name : String, pointer_depth = 1)
      pointer_depth = 0 if pointer_depth < 0
      type_name + ("*" * pointer_depth)
    end

    # Builds the method(s) used to generate the binding to a Qt signals connect
    # method.
    protected def generate_signal_connect_binding_method(signal : Parser::Method)
      proc_fwd = proc_argument("_proc_", Parser::Type::VOID, signal.arguments)

      conn_method = build_method(
        name: signal.connect_name,
        class_name: signal.class_name,
        return_type: CONNECTION_HANDLE_TYPE,
        arguments: [ proc_fwd ],
        crystal_name: "on_#{signal.crystal_name}"
      )

      proc_method = build_method(
        name: "call",
        class_name: proc_fwd.full_name,
        return_type: Parser::Type::VOID,
        arguments: signal.arguments,
      )

      { conn_method, proc_method }
    end

    # Helper to quickly build a `Parser::Method`.
    protected def build_method(name, return_type : Parser::Type, arguments : Array(Parser::Argument), class_name : String, type = Parser::Method::Type::MemberMethod, crystal_name = nil)
      method = Parser::Method.new(
        type: type,
        access: Parser::AccessSpecifier::Public,
        name: name,
        isConst: false,
        className: class_name,
        firstDefaultArgument: nil,
        returnType: return_type,
        arguments: arguments,
      )

      method.crystal_name = crystal_name if crystal_name
      method
    end

    # Builds an argument-type for a `CrystalProc` wrapper for a crystal `Proc`.
    protected def proc_argument(name : String, result : Parser::Type, arguments : Array(Parser::Argument)) : Parser::Argument

      proc_method = build_method(
        name: "unused",
        class_name: "unused",
        return_type: result,
        arguments: arguments,
      )

      crystal_to_cpp = CallAnalyzer::CrystalToCpp.new(@db)
      proc_gen = CallGenerator::CppProcType.new
      call = crystal_to_cpp.analyze(proc_method)

      Parser::Argument.new(
        kind: Parser::Type::Kind::Struct,
        isConst: false,
        isMove: false,
        isReference: false,
        isBuiltin: false,
        isVoid: false,
        pointer: 0,
        baseName: "CrystalProc",
        fullName: proc_gen.generate(call),
        hasDefault: false,
        name: name,
      )
    end

    # If *klass* shall be sub-classed, or not.
    def is_class_subclassed?(klass)
      return false unless klass.has_virtual_methods?
      allow_sub_class = @db[klass.name].try(&.sub_class)

      # It's a `Bool?`, `||` would break it.
      allow_sub_class.nil? || allow_sub_class == true
    end

    # Finds all unique virtual methods in *klass*, including all base-classes,
    # at their highest declaration in the hierarchy.
    protected def unique_virtual_methods(klass, list = [ ] of Tuple(Parser::Class, Parser::Method))

      # Find all virtual methods in the current class
      klass.methods.each do |method|
        next unless method.virtual?
        next if method.filtered?(@db)
        next if list.find(&.last.equals_virtually?(method))
        list << { klass, method }
      end

      # And recurse into all base-classes
      wrapped_base_classes_of(klass) do |base_class|
        if base_class.has_virtual_methods?
          unique_virtual_methods(base_class, list)
        end
      end

      list
    end

    # Yields all base-classes of *klass* which are also wrapped.
    #
    # Note: The code makes the assumption that the first wrapped base class
    # will be used as parent class in Crystal.  All further wrapped base
    # classes will be offered through `#as_BASENAME` conversion methods.
    protected def wrapped_base_classes_of(klass : Parser::Class) : Nil
      klass.bases.each do |base|
        next unless base.public?
        next if base.virtual? # Is this necessary?

        if parent = @classes[base.name]?
          yield parent # `parent : Parser::Class`
        end
      end
    end

    # Non-yielding version.  *range* defines the returned range of indices.
    protected def wrapped_base_classes_of(klass : Parser::Class, range = nil) : Array(Parser::Class)
      list = [] of Parser::Class
      wrapped_base_classes_of(klass){|k| list << k}

      if range
        if range.begin < list.size
          list[range]
        else
          [] of Parser::Class
        end
      else
        list
      end
    end

    # The name of the jump-table setter binding method.
    protected def class_jumptable_setter_name(klass : Parser::Class | String)
      klass = klass.name if klass.is_a?(Parser::Class)
      "bg_#{klass}_JUMPTABLE"
    end

    # Builds a full `Parser::Class` for the sequential *container* in the
    # specified *instantiation*.
    protected def build_sequential_container_class(container, var_type : Parser::Type) : Parser::Class
      klass = container_class(container, { var_type })

      klass.methods << default_class_constructor_method(klass)
      klass.methods << container_access_method(container, klass.name, var_type)
      klass.methods << container_push_method(container, klass.name, var_type)
      klass.methods << container_size_method(container, klass.name)

      klass
    end

    # Builds a method defining a default constructor for *klass*.
    protected def default_class_constructor_method(klass : Parser::Class) : Parser::Method
      build_method(
        type: Parser::Method::Type::Constructor,
        class_name: klass.name,
        name: "",
        return_type: klass.as_type,
        arguments: [ ] of Parser::Argument,
      )
    end

    # Takes a `Configuration::Container` and returns a `Parser::Class` for a
    # specific *instantiation*.
    #
    # Note: The returned class doesn't inherit from anything.  For the crystal
    # generator, see `CrystalGenerator#container_baseclass`.
    protected def container_class(container, instantiation : Enumerable(Parser::Type)) : Parser::Class
      suffix = instantiation.map(&.mangled_name).join("_")
      name = "#{container.class}_#{suffix}"

      Parser::Class.new(name: name, hasDefaultConstructor: true)
    end

    # Builds the access method for the *klass_name* of a instantiated container.
    protected def container_access_method(container : Configuration::Container, klass_name : String, var_type : Parser::Type) : Parser::Method
      idx_type = Parser::Type.builtin_type(CPP_INTEGER_TYPE)
      idx_arg = Parser::Argument.new("index", idx_type)

      build_method(
        name: container.access_method,
        class_name: klass_name,
        arguments: [ idx_arg ],
        return_type: var_type,
        crystal_name: "unsafe_at", # `Indexable#unsafe_at`
      )
    end

    # Builds the push method for the *klass_name* of a instantiated container.
    protected def container_push_method(container : Configuration::Container, klass_name : String, var_type : Parser::Type) : Parser::Method
      var_arg = Parser::Argument.new("value", var_type)
      build_method(
        name: container.push_method,
        class_name: klass_name,
        arguments: [ var_arg ],
        return_type: Parser::Type::VOID,
        crystal_name: "push",
      )
    end

    # Builds the size method for the *klass_name* of a instantiated container.
    protected def container_size_method(container : Configuration::Container, klass_name : String) : Parser::Method
      build_method(
        name: container.size_method,
        class_name: klass_name,
        arguments: [ ] of Parser::Argument,
        return_type: Parser::Type.builtin_type(CPP_INTEGER_TYPE),
        crystal_name: "size", # `Indexable#size`
      )
    end

    # Returns the full C++ type of *container* in *instantiation*.
    protected def container_cpp_type_name(container, instantiation : Array(String)) : String
      "#{container.class}<#{instantiation.join(", ")}>"
    end
  end
end
