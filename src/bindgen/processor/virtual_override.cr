module Bindgen
  module Processor
    # Allows to override C++ `virtual` methods in Crystal sub-classes.
    class VirtualOverride < Base
      include TypeHelper

      # Name of the superclass wrapper structs.
      SUPERCLASS_NAME = "Superclass"

      # Late-initialized in `#process`
      @binding : Graph::Library?

      # Returns `lib Binding`
      private def binding
        @binding.not_nil!
      end

      def process(graph : Graph::Container, _doc : Parser::Document)
        @binding = graph.by_name(Graph::LIB_BINDING).as(Graph::Library)
        super
      end

      def visit_class(klass : Graph::Class)
        return if klass.wrapped_class # Don't change `Impl` classes.
        if subclass?(klass.origin)
          create_subclass(klass)
          create_superclass_wrappers(klass)
        end

        super
      end

      # Ignore `lib`s, else the program will keep on looping on the Crystal
      # jumptable structure.
      def visit_library(_structure)
        nil # Do nothing.
      end

      # Modifies *klass* to allow overriding C++ virtuals.
      private def create_subclass(klass)
        host = Graph::PlatformSpecific.new(platform: Graph::Platform::Cpp)
        klass.nodes.unshift host # We want our structures at the top.
        host.parent = klass

        klass.cpp_sub_class = subclass_name(klass)

        crystal_struct = add_crystal_jumptable_struct(klass)
        cpp_struct = add_cpp_jumptable_struct(klass, host)
        register_table_type(crystal_struct, cpp_struct)

        cpp_subclass = add_cpp_subclass(klass, host)
        add_virtual_forwarders(klass, cpp_subclass)

        cpp_method = add_jumptable_method(klass, cpp_subclass, cpp_struct.name)
        cpp_method.calls[Graph::Platform::Cpp] = build_cpp_jumptable_call(cpp_method.origin)

        hook_initializers(klass, crystal_struct, cpp_method.origin)
        # The C++ virtual methods are built by `Processor::CppWrapper`.
      end

      # Modifies *klass* to allow Crystal subclasses to refer to superclass
      # methods.
      private def create_superclass_wrappers(klass)
        superclass = build_superclass(klass)
        add_superclass_init(superclass, klass)
        add_superclass_method(superclass, klass)
      end

      # If *klass* shall be sub-classed, or not.
      private def subclass?(klass) : Bool
        return false unless klass.has_virtual_methods? && klass.destructible?
        @db.try_or(klass.name, true, &.sub_class)
      end

      # Builds the `Superclass` Crystal struct for the given *klass*.
      private def build_superclass(klass) : Graph::Class
        node = Parser::Class.new(
          name: SUPERCLASS_NAME,
          isClass: false,
          methods: [] of Parser::Method,
        )
        Graph::Class.new(
          origin: node,
          name: node.name,
          parent: klass.platform_specific(Graph::Platform::Crystal),
        )
      end

      # Adds the `#initialize` method to a superclass struct.
      private def add_superclass_init(superclass, klass)
        node = Parser::Method.build(
          class_name: superclass.origin.name,
          name: "",
          return_type: superclass.origin.as_type,
          arguments: [Parser::Argument.new("@myself", klass.origin.as_type)],
          type: Parser::Method::Type::Constructor,
        )
        method = Graph::Method.new(
          origin: node,
          name: node.name,
          parent: superclass,
        )
        method.calls[Graph::Platform::Crystal] =
          CallBuilder::CrystalSuperclassInit.new(@db).build(node, klass.origin)
      end

      # Adds the `#superclass` private method to *klass*.
      private def add_superclass_method(superclass, klass)
        node = Parser::Method.build(
          class_name: klass.name,
          name: "superclass",
          return_type: superclass.origin.as_type,
          arguments: [] of Parser::Argument,
        )
        method = Graph::Method.new(
          origin: node,
          name: node.name,
          parent: klass.platform_specific(Graph::Platform::Crystal),
        )
        method.calls[Graph::Platform::Crystal] =
          CallBuilder::CrystalSuperclass.new(@db).build(superclass.origin)
      end

      # Adds the `BgJumptable` struct for C++ to *klass*.
      private def add_cpp_jumptable_struct(klass, host)
        build_jumptable_struct(klass, host) do |method|
          cpp_jumptable_field method
        end
      end

      # Adds the `BgInherit` struct for C++ to *klass*.
      private def add_cpp_subclass(klass, host)
        klass_type = Parser::Type.parse(jumptable_name klass)
        jump_field = Cpp::Pass.new(@db).to_cpp(klass_type)

        structure = Graph::Struct.new(
          name: subclass_name(klass),
          parent: host,
          fields: {"bgJump" => jump_field},
          base_class: klass.origin.name,
        )

        structure.set_tag(Graph::Struct::INHERIT_CONSTRUCTORS_TAG)
        structure
      end

      private def add_virtual_forwarders(klass, subclass)
        klass.nodes.each do |node|
          next unless node.is_a?(Graph::Method)
          next unless node.origin.virtual?

          # Virtual methods could be split due to default values.  We only want
          # to forward the original method.
          next unless node.origin.origin.nil?
          next if private_override?(klass.origin, node.origin)

          method = Graph::Method.new(
            name: node.name,
            origin: node.origin,
            parent: subclass,
          )

          method.calls[Graph::Platform::Cpp] = build_cpp_forwarder(node.origin, subclass.name, klass.origin.name)
        end
      end

      # Checks if *method* was overriden by *klass* privately.  In this case, we
      # don't allow overriding this method, nor calling it.
      private def private_override?(klass, method)
        if found = klass.find_parent_method(method)
          found.private?
        else
          false
        end
      end

      private def build_cpp_forwarder(method : Parser::Method, class_name, parent_class) : Call
        original = CallBuilder::CppMethodCall.new(@db)
        wrapper = CallBuilder::CppMethod.new(@db)
        to_crystal = CallBuilder::CppToCrystalProc.new(@db)
        proc_name = "_self_->bgJump.#{method.mangled_name}"
        parent_target = "#{parent_class}::#{method.name}"
        target = original.build(method, name: parent_target) unless method.pure? || method.private?

        wrapper.build(
          method: method,
          class_name: class_name,
          target: target,
          virtual_target: to_crystal.build(method, proc_name),
        )
      end

      # Adds the `BgInherit` struct for Crystal to *klass*.
      private def add_crystal_jumptable_struct(klass)
        build_jumptable_struct(klass, binding) do |method|
          crystal_jumptable_field method
        end
      end

      # Builds the `Graph::Struct` jumptable for *klass*, putting it into
      # *parent*.
      private def build_jumptable_struct(klass, parent)
        Graph::Struct.new(
          fields: jumptable_fields(klass) { |m| yield m },
          name: jumptable_name(klass),
          parent: parent,
        )
      end

      # Builds the jumptable fields hash for *klass*, yielding out to let the
      # caller decide the kind of `Call::Result`.
      private def jumptable_fields(klass)
        hsh = {} of String => Call::Result

        klass.nodes.each do |node|
          if method = node.as?(Graph::Method)
            if method.origin.virtual?
              hsh[method.mangled_name] = yield(method)
            end
          end
        end

        hsh
      end

      # Returns the C++ result to the `CrystalProc<T...>` instantiation.
      private def cpp_jumptable_field(method) : Call::Result
        m = method.origin
        proc_type = Parser::Type.proc(m.return_type, m.arguments)
        pass = Cpp::Pass.new(@db)

        Call::Result.new(
          type: proc_type,
          type_name: pass.crystal_proc_name(proc_type),
          reference: false,
          pointer: 0,
          conversion: nil,
        )
      end

      # Returns the Crystal type to a `CrystalProc`
      private def crystal_jumptable_field(method) : Call::Result
        m = method.origin
        proc_type = Parser::Type.proc(m.return_type, m.arguments)

        Call::Result.new(
          type: proc_type,
          type_name: proc_type.base_name,
          reference: false,
          pointer: 0,
          conversion: nil,
        )
      end

      # Adds the `JUMPTABLE` method to *klass*, which will be used to pass the
      # jumptable struct to C++.
      private def add_jumptable_method(klass, cpp_subclass, table_name)
        typer = Cpp::Typename.new
        # Pass by reference.
        table_type = Parser::Type.new(
          baseName: table_name,
          fullName: typer.full(table_name, const: false, pointer: 0, is_reference: true),
          isConst: true,
          isReference: true,
          pointer: 1,
        )

        table_arg = Parser::Argument.new("table", table_type)

        method = Parser::Method.build(
          name: "JUMPTABLE",
          return_type: Parser::Type::VOID,
          arguments: [table_arg],
          class_name: cpp_subclass.name,
        )

        platforms = Graph::Platforms.flags(CrystalBinding, Cpp)
        # Add C++ method
        Graph::Method.new(
          origin: method,
          name: method.name,
          parent: klass.platform_specific(platforms),
        )
      end

      # Builds the C++ wrapper call to set `bgJump`.
      private def build_cpp_jumptable_call(method)
        wrapper = CallBuilder::CppWrapper.new(@db)
        target = CallBuilder::CppCall.new(@db)

        call = target.build(method, body: BgJumpSetBody.new)
        wrapper.build(method, call)
      end

      # Adds the jumptable type to the type database.
      private def register_table_type(crystal_struct, cpp_struct)
        typer = Crystal::Typename.new(@db)

        rules = @db.get_or_add(cpp_struct.name)
        rules.graph_node = crystal_struct
        rules.crystal_type = typer.qualified(crystal_struct.name, in_lib: true)
        rules.cpp_type = cpp_struct.name
        rules.pass_by = TypeDatabase::PassBy::Reference
        rules.copy_structure = true
      end

      # Hooks all `#initialize`rs in *klass*
      private def hook_initializers(klass, crystal_struct, setter)
        klass.nodes.each do |node|
          next unless node.is_a?(Graph::Method)
          hook_initializer(klass, node, crystal_struct, setter)
        end
      end

      # Hooks the *method*, if it's a constructor wrapper.
      private def hook_initializer(klass, method, crystal_struct, setter)
        return unless method.origin.any_constructor?

        # Leave the `unwrap: ` initializer alone.
        return if method.tag?(Graph::Method::UNWRAP_INITIALIZE_TAG)
        call = method.calls[Graph::Platform::Crystal]?

        # Sanity checks
        body = call.try(&.body)
        return unless body.is_a?(Call::HookableBody)
        return unless body.post_hook.nil?

        # Add the hook body, and we're done for now.
        body.post_hook = JumptableHook.new(@db, klass, crystal_struct, setter)
      end

      # Name of the jumptable structure for both C++ and Crystal.
      private def jumptable_name(klass)
        "BgJumptable_#{klass.mangled_name}"
      end

      # The name of the shadow sub-class in C++.
      private def subclass_name(klass)
        "BgInherit_#{klass.mangled_name}"
      end

      # Body for `CallBuilder::CppCall`, setting the `bgJump` member in C++.
      class BgJumpSetBody < Call::Body
        def to_code(call : Call, _platform : Graph::Platform) : String
          pass_arg = call.arguments.first.call
          %[_self_->bgJump = (#{pass_arg})]
        end
      end

      # Hook to set the jumptable in an initializer.
      class JumptableHook < Call::Body
        def initialize(@db : TypeDatabase, @klass : Graph::Class, @table : Graph::Struct, @setter : Parser::Method)
        end

        # Generates a piece of macro code, to be evaluated by the Crystal compiler
        # at compile-time of the user application, which gathers all overwritten
        # virtual methods into the `forwarded` macro variable.
        private def generate_initialize_virtual_methods_macro(methods, b)
          names = methods.map(&.origin.crystal_name).join(" ")

          b << %[{%\n]
          b << %[  methods = [] of Def\n]
          b << %[  ([@type] + @type.ancestors).select(&.<(#{@klass.name})).map{|x| methods = methods + x.methods}\n]
          b << %[  forwarded = methods.map(&.name.stringify).select{|m| %w[ #{names} ].includes?(m) }.uniq\n]
          b << %[%}\n]
        end

        private def all_virtual_methods : Array(Graph::Method)
          # TODO: Support for overloaded virtual methods
          # TODO: Look through parent classes.
          list = [] of Graph::Method

          @klass.nodes.each do |node|
            next unless node.is_a?(Graph::Method)
            list << node if node.origin.virtual?
          end

          list
        end

        def to_code(call : Call, platform : Graph::Platform) : String
          builder = CallBuilder::CrystalFromCpp.new(@db)
          typer = Crystal::Typename.new(@db)
          table_type = typer.qualified(@table.name, in_lib: true)
          methods = all_virtual_methods

          String.build do |b|
            b << "{% begin %}\n"
            generate_initialize_virtual_methods_macro methods, b
            b << "jump_table = #{table_type}.new(\n"
            methods.each do |method|
              name = method.origin.crystal_name
              functor = builder.build(method.origin)
              code = functor.body.to_code(functor, Graph::Platform::Crystal)
              b << "  #{method.mangled_name}: BindgenHelper.wrap_proc("
              b << "{% if forwarded.includes?(#{name.inspect}) %} #{code} {% else %} nil {% end %}"
              b << "),\n"
            end

            b << ")\n"

            # Call the JUMPTABLE set function
            b << "Binding.#{@setter.mangled_name}(result, pointerof(jump_table))\n"
            b << "{% end %}"
          end
        end
      end
    end
  end
end
