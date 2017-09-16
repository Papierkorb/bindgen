module Bindgen
  module Graph
    # Pathing logic for the graph.  See `Path.local` to find a locally-qualified
    # path between two nodes.  Or use `.from` to build a path from a string.
    #
    # The structure doesn't store any origin by itself.
    struct Path
      # Node path.  If `nil`, the path points to itself.
      getter nodes : Array(String)?

      def initialize(@nodes = [ ] of String)
      end

      # Is this a global path?
      def global?
        nodes = @nodes

        if nodes.first?.try(&.empty)
          true
        else
          false
        end
      end

      # Is this a local path?
      def local?
        !global?
      end

      # Returns a global path from this local path, starting look-up at *base*.
      # Does a full look-up under the hood, thus, the path has to be valid.
      def to_global(base : Node) : Path
        target = lookup(base)

        if target.nil?
          raise "Path #{self} does not exist in #{base.path_name}"
        end

        if target.parent
          "::" + target.path_name
        else # Self-path lookup on the root.
          "::"
        end
      end

      # Gives the path as Crystal constants look-up path.
      def to_s(io)
        nodes = @nodes

        if nodes.nil? # Path to itself
          io << ""
        elsif nodes.empty? # Force lookup starting at the global scope
          io << "::"
        else # Normal constant lookup path
          io << nodes.join("::")
        end
      end

      # Much like `#to_s`, but tells the user when this path points to itself.
      def inspect(io)
        if @nodes.nil?
          io << "self"
        else
          to_s(io)
        end
      end

      # Returns a new `Path` on *path*.  Supports generic parts.
      #
      # BUG: Doesn't support nested generics, like `Foo(Bar(Baz))::Quux`.
      def self.from(path : String) : Path
        new path.gsub(/\([^)]+\)/, "").split("::")
      end

      # ditto
      def self.from(path : Enumerable(String)) : Path
        new path.to_a
      end

      # Returns a self-referencing path.
      def self.from(path : Nil) : Path
        new nil
      end

      # Finds the local path to go from *node* to *wants*, in terms of constant
      # resolution for Crystal.
      #
      # BUG: Fails if `Foo::Node`, `Foo::Wants` and `Foo::Node::Wants` exist.
      # The affected branches are marked with `!!`.
      def self.local(node : Graph::Node, wants : Graph::Node) : Path
        if node == wants # It wants itself.  Nothing to do.
          Path.new(nil)
        elsif node.parent == wants.parent # !!
          Path.new([ wants.name ]) # Locally qualified name suffices
        else
          wants_path = wants.full_path
          common, index = last_common(node.full_path, wants_path)

          if common # We have a common ancestor node
            if common == wants # *node* is inside *wants*
              Path.new([ wants.name ])
            else # !!
              Path.new(wants_path[(index + 1)..-1].map(&.name))
            end
          else # No common parts in the path.  Fall back to using the full path.
            Path.new(wants_path.map(&.name))
          end
        end
      end

      # Does a local look-up starting at *base* for *path*.  The look-up will
      # begin in *base* itself.  If not found, it'll try to find the path by
      # going up to the parent(s).
      #
      # If the *path* starts with `::` (An empty element), the look-up will
      # always start at the global scope.
      #
      # If not found, returns `nil`.
      def lookup(base : Node) : Node?
        nodes = @nodes
        if nodes.nil? # Handle self lookup.
          base
        elsif nodes.empty? # We don't have a global scope by itself.
          nil
        else
          do_lookup(base, nodes)
        end
      end

      # Implements the actual look-up logic without the corner cases.
      private def do_lookup(base, path) : Node?
        root = base.find_root
        base, path = lookup_global_check(root, base, path)

        # Try lookup of the path, going up to the parent once if not found.
        while base
          found = try_lookup(base, path)
          return found if found
          base = base.parent
        end

        # One last try: Support a local-"global"-path like `Qt::Object`.
        if path.first == root.name
          return try_lookup(root, path[1..-1])
        end

        nil # Not found
      end

      # Tries to find *path* starting in *node*.
      private def try_lookup(node, path) : Node?
        path.each do |local_name|
          return nil unless node.is_a?(Container)

          # Manually traverse to also search in `PlatformSpecific` nodes
          node = find_in_container(node, local_name)
        end

        # Maybe found!  May be `nil` if the last part of the path was not found.
        node
      end

      # Searches in *container* for a node called *name*.  Also traverses
      # `PlatformSpecific` containers automatically.
      private def find_in_container(container, name)
        container.nodes.each do |node|
          if node.is_a?(PlatformSpecific) # Support platform-specific
            if found = find_in_container(node, name) # Recurse
              return found
            end
          end

          return node if node.name == name
        end

        nil # Not found.
      end

      # Helper for `#do_lookup`: Checks if *path* starts at the global level.
      private def lookup_global_check(root, base, path)
        if path.first.empty? # Force start at the root?
          base = root

          if path[1] != base.name # Make sure we go into our namespace
            return { nil, path }
          end

          path = path[2..-1] # Skip first two elements
        end

        { base, path }
      end

      # Finds the last common element in the lists *a* and *b*, and returns it.
      private def self.last_common(a, b)
        found = nil
        index = -1

        a.each_with_index do |l, idx|
          r = b[idx]?

          if l == r
            found = l
            index = idx
          else
            break
          end
        end

        { found, index }
      end
    end
  end
end
