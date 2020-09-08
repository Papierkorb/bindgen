module Bindgen
  module Processor
    # Copies all classes into `lib struct`s which have their `copy_structure`
    # set to `true` in the type database.
    #
    # Has to be run before the `CrystalBinding` processor.
    class CopyStructs < Base
      def process(graph : Graph::Node, doc : Parser::Document)
        root = graph.by_name(Graph::LIB_BINDING)

        @db.each do |cpp_name, rules|
          next unless rules.copy_structure # Only care about copy-able structures

          klass = find_structure(doc, cpp_name)
          graph = rules.graph_node.as(Graph::Class)
          next if graph.structure # Already has a structure?

          graph.structure = copy_structure(klass, root)
        end
      end

      # Finds the class *name* in the *doc*.  If not found, or if no fields have
      # been found, raises.
      private def find_structure(doc, name) : Parser::Class
        klass = doc.classes[name]?

        if klass.nil? # We know about this, right?
          raise "Can't copy structure of unknown class #{name.inspect}"
        end

        if klass.fields.empty? # We can actually copy something
          raise "Can't copy structure of class #{name.inspect}: It has no fields"
        end

        klass
      end

      # Copies the structure of *klass* into the `lib` *root*.
      private def copy_structure(klass, root)
        typename = Crystal::Typename.new(@db)
        name = typename.binding(klass.as_type).first

        Graph::Struct.new( # Add the struct into the graph
          name: name,
          fields: fields_to_graph(klass.fields),
          parent: root,
        )
      end

      # Turns *fields* into a hash of `Call::Result`s we can store in the graph.
      private def fields_to_graph(fields : Enumerable(Parser::Field))
        calls = {} of String => Call::Result
        pass = Crystal::Pass.new(@db)
        argument = Crystal::Argument.new(@db)

        fields.each_with_index do |field, idx|
          result = pass.to_binding(field)
          var_name = argument.name(field.crystal_name, idx)

          calls[var_name] = result
        end

        calls
      end
    end
  end
end
