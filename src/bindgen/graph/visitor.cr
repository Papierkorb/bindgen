module Bindgen
  module Graph
    # A `Graph::Node` visitor module.  Use `#visit_node` as entry-point, and
    # override the remaining `#visit_X` methods as you require.
    module Visitor
      # A visitor including this module will be allowed to *delete* a node out
      # of a `Container`, while iterating over that same container, from within
      # an inner visitor method.
      module MayDelete
        include Visitor

        # Visits all children of *container*.  The *container*s nodes list is
        # copied internally before iterating.  It is thus acceptable to
        # **delete** items from the `#visit_X` method called by this.
        def visit_children(container : Container)
          container.nodes.dup.each do |child|
            visit_node(child)
          end
        end
      end

      # Checks if *node* shall be visited.  Can be overriden in the host class
      # to only visit specific nodes.
      #
      # See `Generator::Base#visit_node?` for an example.
      def visit_node?(node : Node)
        true
      end

      # Visits *node*, calling out to the correct handler method.  Certain nodes
      # can be ignored by overriding `#visit_node?` and returning `false` from
      # there.
      def visit_node(node : Node)
        return unless visit_node?(node) # Do we care?

        case node
        when Graph::Alias
          visit_alias(node)
        when Graph::Class
          visit_class(node)
        when Graph::Constant
          visit_constant(node)
        when Graph::Enum
          visit_enum(node)
        when Graph::Library
          visit_library(node)
        when Graph::Method
          visit_method(node)
        when Graph::Namespace
          visit_namespace(node)
        when Graph::Struct
          visit_struct(node)
        when Graph::CppUnion
          visit_union(node)
        when Graph::PlatformSpecific
          visit_platform_specific(node)
        else
          raise "BUG: Missing case for type #{node.class} in Graph::Visitor"
        end
      end

      # Visits all children of *container*.
      def visit_children(container : Container)
        container.nodes.each do |child|
          visit_node(child)
        end
      end

      # Visits a `Graph::Alias`.
      def visit_alias(alias_name)
      end

      # Visits a `Graph::Class`.  The default implementation calls
      # `#visit_children` to visit all child nodes.
      def visit_class(klass)
        visit_children(klass)
      end

      # Visits a `Graph::Constant`.
      def visit_constant(constant)
      end

      # Visits a `Graph::Enum`.
      def visit_enum(enumeration)
      end

      # Visits a `Graph::Library`.  The default implementation calls
      # `#visit_children` to visit all child nodes.
      def visit_library(library)
        visit_children(library)
      end

      # Visits a `Graph::Method`.
      def visit_method(method)
      end

      # Visits a `Graph::Namespace`.  The default implementation calls
      # `#visit_children` to visit all child nodes.
      def visit_namespace(ns)
        visit_children(ns)
      end

      # Visits a `Graph::Struct`.
      def visit_struct(structure)
        visit_children(structure)
      end

      # Visits a `Graph::CppUnion`.
      def visit_union(structure)
        visit_children(structure)
      end

      # Visits a `Graph::PlatformSpecific`.
      def visit_platform_specific(specific)
        visit_children(specific)
      end
    end
  end
end
