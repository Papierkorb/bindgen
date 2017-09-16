module Bindgen
  module Graph
    # Base class for nodes containing multiple other `Node`s.
    abstract class Container < Node
      # Child nodes
      getter nodes = [ ] of Node

      # Finds the first child node called *name*.  If none found, raises.
      def by_name(name) : Node
        by_name?(name) || raise("Did not find node #{name.inspect} in #{full_path}")
      end

      # Finds the first child node called *name*.  If none found, returns `nil`.
      def by_name?(name) : Node?
        @nodes.find(&.name.== name)
      end
    end
  end
end
