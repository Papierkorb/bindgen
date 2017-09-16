module Bindgen
  module Processor
    # Processor wrapping single- and multiple-inheritance.
    #
    # Only non-private wrapped classes are possible candidates for this.  Of
    # all candidates, the first one is chosen as parent class in Crystal. All
    # others get a `#as_X() : X` casting method.
    #
    # Take this C++ class: `class Foo : public Bar, public Baz`
    # If both `Bar` and `Baz` are wrapped, the resulting Crystal wrapper will
    # look like this:
    #
    # ```
    # class Foo < Bar # First one is inherited
    #   def as_baz : Baz; ...; end # Later ones converted
    # end
    # ```
    class Inheritance < Base
      def visit_class(klass : Graph::Class)
        # Find all non-private, wrapped bases.
        bases = klass.origin.bases.reject{|b| b.private? || b.virtual?}
        wrapped = wrapped_classes(bases)

        return if wrapped.empty? # Nothing to do.

        # We inherit the first wrapped base-class in Crystal.
        klass.base_class = Graph::Path.local(klass, wrapped.first).to_s

        # For all other base-classes, we provide `#as_X` methods.
        if wrapped.size > 1
          add_conversion_methods(klass, wrapped[1..-1])
        end
      end

      # Adds all conversion methods from *klass* to *bases*.
      private def add_conversion_methods(klass, bases)
        bases.each do |base|
          add_conversion_method(klass, base)
        end
      end

      # Adds a `#as_BASE` method to *klass*.  The name of *base* is demodulized:
      # Asumming a base-name like `Foo::BarBaz`, the method will be called
      # `#as_bar_baz`.
      private def add_conversion_method(klass, base)
        converter = conversion_method(klass, base)
        graph = Graph::Method.new(origin: converter, name: converter.crystal_name, parent: klass)
        pass = Cpp::Pass.new(@db)

        # The Crystal wrapper and bindings will be generated automatically for us later.
        call = CallBuilder::CppCall.new(@db)
        wrapper = CallBuilder::CppWrapper.new(@db)
        target = call.build(converter, body: CastBody.new)

        graph.calls[Graph::Platform::Cpp] = wrapper.build(converter, target)
      end

      # Builds a method converting *from* in *to*.
      private def conversion_method(from, to)
        name, _ = Crystal::Typename.new(@db).wrapper(to.origin.as_type)
        demodulized = name.gsub(/.*::/, "").underscore

        Parser::Method.build(
          name: "AS_#{to.mangled_name}",
          return_type: to.origin.as_type(pointer: 1),
          arguments: [ ] of Parser::Argument,
          class_name: from.origin.name,
          crystal_name: "as_#{demodulized}",
        )
      end

      # Finds all wrapped classes in *bases*.
      private def wrapped_classes(bases) : Array(Graph::Class)
        nodes = [ ] of Graph::Class

        bases.each do |base|
          # Ask the type database for the graph node.  The `Graph::Builder` set
          # these initially for us.
          node = @db[base.name]?.try(&.graph_node).as?(Graph::Class)
          nodes << node if node
        end

        nodes
      end

      # C++ body doing a `static_cast<T*>(_self_)`.
      class CastBody < Call::Body
        def to_code(call : Call, _platform : Graph::Platform) : String
          typer = Cpp::Typename.new
          type_name = typer.full(call.result)
          "static_cast<#{type_name}>(_self_)"
        end
      end
    end
  end
end
