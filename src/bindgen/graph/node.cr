module Bindgen
  module Graph
    # A node in the method graph.  Base class of all elements in the graph.
    abstract class Node
      # Parent node, or `nil` if it's this node has no parent.
      property parent : Node?

      # Name of this node.
      getter name : String

      def initialize(@name, parent = nil)
        @parent = parent

        if parent.is_a?(Container)
          parent.nodes << self
        end
      end

      # Is this node kind a constant in Crystal?
      def constant? : Bool
        true # Most are constants, so default to it.
      end

      # Gives a list of nodes, going from the root node all the way to this
      # node.  This node will be the last item in the result, and the root
      # will be the first.
      #
      # The result list does not contain any `PlatformSpecific` nodes, even if
      # one was encountered while traversing.
      def full_path : Array(Node)
        p = @parent
        path = [ self ] of Node

        while p # Iterate over all parents
          path << p unless p.is_a?(PlatformSpecific)
          p = p.parent
        end

        # The path is from child to root, but root to child is more convenient.
        path.reverse
      end

      # Node-kind prefix for a nicely readable path, according to Crystal.
      def crystal_prefix : String
        "::"
      end

      # Returns the qualified path name to this node, starting in the global
      # scope.
      #
      # See also `#full_path`.
      def path_name : String
        full_path.each.map(&.name).join("::")
      end

      # Gives a humanly-readable path string, formatted for Crystal.
      def diagnostics_path : String
        p = parent # Skip direct parent if it's a platform specific
        p = p.parent if p.is_a?(PlatformSpecific)

        parent_path = p.try(&.path_name).to_s
        parent_path + crystal_prefix + @name
      end

      # The kind name of this node for diagnostic purposes.
      def kind_name : String
        self.class.name.sub(/.*::/, "")
      end

      # Finds the root of this node.  The root node is the one with a `#parent`
      # of `nil`.
      def find_root : Node
        if p = @parent
          p.find_root
        else
          self
        end
      end
    end
  end
end
