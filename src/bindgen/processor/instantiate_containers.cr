module Bindgen
  module Processor
    # Generates a class for each to-be instantiated container type.
    # This processor must be run *before* any processor that generates platform
    # specific `Call`s, like `Crystal` or `Cpp`.
    class InstantiateContainers < Base
      # Name of the "standard" built-in integer C++ type.  Required for the
      # generated `#size` method, and `#unsafe_fetch` of sequential containers.
      CPP_INTEGER_TYPE = "int"

      # Module for sequential containers
      SEQUENTIAL_MODULE = "BindgenHelper::SequentialContainer"

      # Module for associative containers
      ASSOCIATIVE_MODULE = "BindgenHelper::AssociativeContainer"

      def process(graph : Graph::Node, _doc : Parser::Document)
        root = graph.as(Graph::Container)

        @config.containers.each do |container|
          instantiate_container(container, root)
        end
      end

      # Instantiates the *container* (Of any type), placing the built classes
      # into *root*.
      private def instantiate_container(container, root)
        case container.type
        when .sequential?
          add_sequential_containers(container, root)
        when .associative?
          raise "Associative containers are not yet supported."
        else
          raise "BUG: Missing case for #{container.type.inspect}"
        end
      end

      # Adds all instances of the sequential *container* into *root*.
      private def add_sequential_containers(container, root)
        container.instantiations.each do |instance|
          check_sequential_instance! container, instance
          add_sequential_container(container, instance, root)
        end
      end

      # Instantiates a single *container* *instance* into *root*.
      private def add_sequential_container(container, instance, root)
        builder = Graph::Builder.new(@db)
        var_type = Parser::Type.parse(instance.first)
        klass = build_sequential_class(container, var_type)

        add_cpp_typedef(root, klass, container, instance)
        set_sequential_container_type_rules(klass.name, klass, var_type)

        graph = builder.build_class(klass, klass.name, root)
        graph.set_tag(Graph::Class::FORCE_UNWRAP_VARIABLE_TAG)
        graph.included_modules << container_module(SEQUENTIAL_MODULE, var_type)
      end

      # Generates the Crystal module name of a container class.
      private def container_module(kind, *types)
        pass = Crystal::Pass.new(@db)
        typer = Crystal::Typename.new(@db)
        args = types.map { |t| typer.full pass.to_wrapper(t) }.join(", ")

        "#{kind}(#{args})"
      end

      # Adds a `tyepedef Container<T...> Container_T...` for C++.  Also stores
      # the alias in the type-database.
      private def add_cpp_typedef(root, klass, container, instance)
        pass = Cpp::Pass.new(@db)
        typer = Cpp::Typename.new
        type = Parser::Type.parse(typer.template_class(container.class, instance))

        # Alias e.g. `QList_QObject_X` to `QList<QObject *>`
        if @db[type.base_name]?.nil?
          @db.get_or_add(type.base_name).alias_for = klass.name
        end

        # On top for C++!
        host = Graph::PlatformSpecific.new(platform: Graph::Platform::Cpp)
        root.nodes.unshift host
        host.parent = root

        origin = Call::Result.new(
          type: type,
          type_name: type.full_name,
          reference: false,
          pointer: 0,
        )

        Graph::Alias.new( # Build the `typedef`.
          origin: origin,
          name: klass.name,
          parent: host,
        )
      end

      # Updates the *rules* of the container *klass*, carrying a *var_type*.
      # The rules are changed to convert from and to the binding type.
      private def set_sequential_container_type_rules(cpp_type_name, klass : Parser::Class, var_type)
        pass = Crystal::Pass.new(@db)

        rules = @db.get_or_add(cpp_type_name)
        result = pass.to_wrapper(var_type)

        rules.builtin = true # `Void` is built-in!
        rules.pass_by = TypeDatabase::PassBy::Pointer
        rules.wrapper_pass_by = TypeDatabase::PassBy::Value
        rules.binding_type = "Void"
        rules.crystal_type ||= "Enumerable(#{result.type_name})"
        rules.cpp_type ||= cpp_type_name

        if rules.to_crystal.no_op?
          rules.to_crystal = Template.from_string(
            "#{klass.name}.new(unwrap: %)", simple: true)
        end
        if rules.from_crystal.no_op?
          rules.from_crystal = Template.from_string(
            "BindgenHelper.wrap_container(#{klass.name}, %).to_unsafe", simple: true)
        end
        if rules.from_cpp.no_op?
          rules.from_cpp = Template.from_string(@db.cookbook.value_to_pointer(klass.name))
        end
        if rules.to_cpp.no_op?
          rules.to_cpp = Template.from_string(@db.cookbook.pointer_to_reference(klass.name))
        end
      end

      # Name of *container* with *instance* for diagnostic purposes.
      private def diagnostics_name(container, instance)
        typer = Cpp::Typename.new
        typer.template_class(container.class, instance)
      end

      # Checks if *instance* of *container* is valid.  If not, raises.
      private def check_sequential_instance!(container, instance)
        if instance.size != 1
          raise "Container #{diagnostics_name container, instance} was expected to have exactly one argument"
        end
      end

      # Builds a full `Parser::Class` for the sequential *container* in the
      # specified *instantiation*.
      private def build_sequential_class(container, var_type : Parser::Type) : Parser::Class
        klass = container_class(container, {var_type})

        klass.methods << default_constructor_method(klass)
        klass.methods << access_method(container, klass.name, var_type)
        klass.methods << push_method(container, klass.name, var_type)
        klass.methods << size_method(container, klass.name)

        klass
      end

      # Takes a `Configuration::Container` and returns a `Parser::Class` for a
      # specific *instantiation*.
      #
      # Note: The returned class doesn't include any modules.  This is done on
      # the `Graph::Class` of the Crystal wrapper, see `#container_module`.
      private def container_class(container, instantiation : Enumerable(Parser::Type)) : Parser::Class
        suffix = instantiation.map(&.mangled_name).join("_")
        klass_type = Parser::Type.parse(container.class)
        name = "Container_#{klass_type.mangled_name}_#{suffix}"

        Parser::Class.new(name: name, has_default_constructor: true)
      end

      # Builds a method defining a default constructor for *klass*.
      private def default_constructor_method(klass : Parser::Class)
        Parser::Method.build(
          type: Parser::Method::Type::Constructor,
          class_name: klass.name,
          name: "",
          return_type: klass.as_type,
          arguments: [] of Parser::Argument,
        )
      end

      # Builds the access method for the *klass_name* of a instantiated container.
      private def access_method(container : Configuration::Container, klass_name : String, var_type : Parser::Type) : Parser::Method
        idx_type = Parser::Type.builtin_type(CPP_INTEGER_TYPE)
        idx_arg = Parser::Argument.new("index", idx_type)

        Parser::Method.build(
          name: container.access_method,
          class_name: klass_name,
          arguments: [idx_arg],
          return_type: var_type,
          crystal_name: "unsafe_fetch", # Will implement `Indexable#unsafe_fetch`
        )
      end

      # Builds the push method for the *klass_name* of a instantiated container.
      private def push_method(container : Configuration::Container, klass_name : String, var_type : Parser::Type) : Parser::Method
        var_arg = Parser::Argument.new("value", var_type)
        Parser::Method.build(
          name: container.push_method,
          class_name: klass_name,
          arguments: [var_arg],
          return_type: Parser::Type::VOID,
          crystal_name: "push",
        )
      end

      # Builds the size method for the *klass_name* of a instantiated container.
      private def size_method(container : Configuration::Container, klass_name : String) : Parser::Method
        Parser::Method.build(
          name: container.size_method,
          class_name: klass_name,
          arguments: [] of Parser::Argument,
          return_type: Parser::Type.builtin_type(CPP_INTEGER_TYPE),
          crystal_name: "size", # `Indexable#size`
        )
      end
    end
  end
end
