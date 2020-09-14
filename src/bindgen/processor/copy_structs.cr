module Bindgen
  module Processor
    # Copies all classes into `lib struct`s which have their `copy_structure`
    # set to `true` in the type database.
    #
    # Has to be run before the `CrystalBinding` processor.
    class CopyStructs < Base
      def process(graph : Graph::Node, doc : Parser::Document)
        root = graph.by_name(Graph::LIB_BINDING)

        unused_structures = find_unused_structures(doc)

        @db.each do |cpp_name, rules|
          next unless rules.copy_structure # Only care about copy-able structures

          klass = find_structure(doc, cpp_name)
          graph = rules.graph_node.as(Graph::Class)
          next if graph.structure # Already has a structure?
          next if unused_structures.includes?(graph) # Will be inlined?

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
          fields: fields_to_graph(klass),
          parent: root,
          union: klass.c_union?,
        )
      end

      # Turns *klass*'s fields into a hash of `Call::Result`s we can store in
      # the graph.
      private def fields_to_graph(klass)
        calls = {} of String => Call::Result
        add_fields_to_graph(klass, calls)
        calls
      end

      # Helper for `#fields_to_graph`.  Recursively descends into inlinable
      # member types.
      private def add_fields_to_graph(klass : Parser::Class, calls)
        pass = Crystal::Pass.new(@db)
        argument = Crystal::Argument.new(@db)

        klass.fields.each_with_index do |field, idx|
          field_klass, inlinable = get_field_type(klass, field)

          if field_klass && inlinable
            add_fields_to_graph(field_klass.origin, calls)
          else
            result = pass.to_binding(field)
            var_name = argument.name(field.crystal_name, idx)

            calls[var_name] = result
          end
        end
      end

      # Locates classes whose structures aren't needed due to being inlined in a
      # parent structure.  Applies to unnamed structure members of anonymous
      # types.
      private def find_unused_structures(doc : Parser::Document)
        nodes = Set(Graph::Class).new
        nodes.compare_by_identity

        @db.each do |cpp_name, rules|
          next unless rules.copy_structure

          if klass = doc.classes[cpp_name]?
            klass.fields.each do |field|
              field_klass, inlinable = get_field_type(klass, field)
              nodes << field_klass if field_klass && inlinable
            end
          end
        end

        nodes
      end

      # Looks up the class of the *field* inside the given *klass*.  Returns the
      # graph node, and whether the field's own data members can be inlined.
      private def get_field_type(klass, field) : {Graph::Class?, Bool}
        rules = @db[field.base_name]?
        node = rules.try(&.graph_node).as?(Graph::Class)

        inlinable = case
        when !field.name.empty?
          false # named members are never inlined
        when !rules.try(&.copy_structure)
          false # cannot inline field if its structure isn't copied
        when !node.try(&.origin.anonymous?)
          false # named types are never inlined
        when klass.c_union? != node.try(&.origin.c_union?)
          false # a C union cannot be inlined inside a struct, and vice-versa
        else
          true
        end

        {node, inlinable}
      end
    end
  end
end
