module Bindgen
  module Graph
    # Pathing logic for the graph.  See `Path.local` to find a locally-qualified
    # path between two nodes.  Or use `.from` to build a path from a string.
    #
    # The structure doesn't store any origin by itself.
    struct Path
      # The names of the path at each namespace.
      getter parts : Array(String)

      # Is this a global path?
      getter? global : Bool

      def_equals_and_hash @parts, @global

      protected def initialize(@parts, @global)
      end

      # Returns the `Path` with the parts in *range*.  The new `Path` is global
      # only if it includes the first part of this `Path` and this `Path` is
      # also global.
      def [](range : Range) : Path
        range = normalize_range(range)
        Path.new(@parts[range], global? && range.includes?(0))
      end

      # Returns the `Path` excluding the last part in `#nodes`, thus pointing
      # to the parent of this path.  Returns a global path if this path is also
      # global.  Raises if this is an empty path.
      def parent : Path
        raise IndexError.new("parent called on empty path") if empty?
        Path.new(@parts[0..-2], global?)
      end

      # Returns the local `Path` with only the last part in `#nodes`, thus
      # pointing at the child in `#parent`.  Raises if this is an empty path.
      def last : Path
        raise IndexError.new("last called on empty path") if empty?
        Path.new(@parts[-1..-1], false)
      end

      # Returns the last part of this path.  Raises if this is an empty path.
      def last_part : String
        raise IndexError.new("last_part called on empty path") if empty?
        @parts.last
      end

      # Combines the *other* path into this path.  If the other path is global,
      # simply returns *other*.  Otherwise, the new path contains the parts from
      # this path, followed by the parts from *other*.
      def join(other : Path) : Path
        if other.global?
          other
        else
          Path.new(@parts + other.parts, self.global?)
        end
      end

      # :nodoc:
      protected def join!(other : Path)
        if other.global?
          @parts = other.parts.dup
          @global = true
        else
          @parts.concat(other.parts)
        end
        self
      end

      # Is this an empty path?
      delegate empty?, to: @parts

      # Does this path point to itself?
      def self_path?
        empty? && !global?
      end

      # Is this a local path?  Also `true` if this is a `#self_path?` path.
      def local?
        !global?
      end

      # Returns a global path from this local path, starting look-up at *base*.
      # Does a full look-up under the hood, thus, the path has to be valid.
      #
      # If this is already a `#global?` path, it is returned without further
      # checks.
      def to_global(base : Node) : Path
        return self if global?
        target = lookup(base)

        if target.nil?
          raise "Path #{self} does not exist in #{base.path_name}"
        end

        if target.parent
          Path.new(target.full_path.map(&.name), true)
        else # Self-path lookup on the root.
          Path.global_root
        end
      end

      # Gives the path as Crystal constants look-up path.
      def to_s(io)
        io << "::" if global?
        io << parts.join("::")
      end

      # Much like `#to_s`, but tells the user when this path points to itself.
      def inspect(io)
        if self_path?
          io << "self"
        else
          to_s(io)
        end
      end

      # Returns a new `Path` on *path*.  Supports generic parts.
      #
      # BUG: Doesn't support nested generics, like `Foo(Bar(Baz))::Quux`.
      def self.from(path : String) : Path
        if path == ""
          self_path
        elsif path == "::"
          global_root
        else
          parts = path.gsub(/\([^)]+\)/, "").split("::")
          if global = parts.first?.try(&.empty?)
            parts.shift
          end
          parts.pop if parts.last?.try(&.empty?)
          new(parts, global || false)
        end
      end

      # :ditto:
      def self.from(path : Path) : Path
        new(path.parts.dup, path.global?)
      end

      # Returns a new `Path` formed by concatenating the given paths.
      def self.from(first_path : String | Path, *remaining : String | Path) : Path
        remaining.reduce(from(first_path)) do |path, other|
          path.join!(other.is_a?(Path) ? other : from(other))
        end
      end

      # :ditto:
      def self.from(path : Enumerable(String | Path)) : Path
        from(*path)
      end

      # Returns a self-referencing path.
      def self.self_path : Path
        new([] of String, false)
      end

      # Returns a path that refers to the global root.
      def self.global_root : Path
        new([] of String, true)
      end

      # Finds the local path to go from *node* to *wants*, in terms of constant
      # resolution for Crystal.
      #
      # BUG: Fails if `Foo::Node`, `Foo::Wants` and `Foo::Node::Wants` exist.
      # The affected branches are marked with `!!`.
      def self.local(node : Node, wants : Node) : Path
        if node == wants # It wants itself.  Nothing to do.
          Path.self_path
        elsif node.parent == wants.parent # !!
          new([wants.name], false) # Locally qualified name suffices
        else
          wants_path = wants.full_path
          common, index = last_common(node.full_path, wants_path)

          if common            # We have a common ancestor node
            if common == wants # *node* is inside *wants*
              new([wants.name], false)
            else # !!
              new(wants_path[(index + 1)..-1].map(&.name), false)
            end
          else # No common parts in the path.  Fall back to using the full path.
            new(wants_path.map(&.name), false)
          end
        end
      end

      # Returns the global path to *node*.
      def self.global(node : Node) : Path
        new(node.full_path.map(&.name), true)
      end

      # Does a local look-up starting at *base* for *path*.  The look-up will
      # begin in *base* itself.  If not found, it'll try to find the path by
      # going up to the parent(s).
      #
      # If the *path* starts with `::` (An empty element), the look-up will
      # always start at the global scope.  If *path* is exactly `::`, the root
      # node (not the global root) is returned.  Otherwise, the first part of
      # the path must be the name of the root node: `::RootName::And::So::On`
      # instead of `::And::So::On`.
      #
      # If not found, returns `nil`.  This method does *not* raise.
      def lookup(base : Node) : Node?
        if empty? # Handle self-paths and global root
          return global? ? base.find_root : base
        end

        first_part = @parts.first

        if global?
          root = base.find_root
          try_lookup_at(root) if first_part == root.name
        else
          while base
            # Child nodes have higher priority over siblings.  If a child
            # matches *first_part*, lookup will stop after this iteration;
            # otherwise, siblings in *node*'s enclosing namespace are searched
            # (on the first iteration this includes the original *base* itself).
            node = find_in_container(base, first_part) || base
            return try_lookup_at(node) if first_part == node.name

            # Try parent namespaces
            base = base.unspecific_parent
          end
        end
      end

      # Helper for `#lookup`.  Tries to locate this path in a namespace
      # enclosing *node*.  Assumes the path is local and does not retry lookup
      # in parent namespaces.
      private def try_lookup_at(node) : Node?
        @parts.each(within: 1..) do |local_name|
          # Lookup is only supported on container nodes
          return nil unless node.is_a?(Container)

          # Manually traverse to also search in `PlatformSpecific` nodes
          node = find_in_container(node, local_name)
        end

        # Maybe found!  May be `nil` if the last part was not found.
        node
      end

      # Searches in *container* for a node called *name*.  Also traverses
      # `PlatformSpecific` containers automatically.
      private def find_in_container(container, name)
        container.nodes.each do |node|
          if node.is_a?(PlatformSpecific)            # Support platform-specific
            if found = find_in_container(node, name) # Recurse
              return found
            end
          else
            return node if node.name == name
          end
        end

        nil # Not found.
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

        {found, index}
      end

      # Normalizes a range expression, required for `#[](Range)`.  Based on
      # `Indexable.range_to_index_and_count` (an undocumented method).
      private def normalize_range(range)
        collection_size = @parts.size

        start_index = range.begin
        if start_index.nil?
          start_index = 0
        else
          start_index += collection_size if start_index < 0
          raise IndexError.new if start_index < 0
        end

        end_index = range.end
        if end_index.nil?
          count = collection_size - start_index
        else
          end_index += collection_size if end_index < 0
          end_index -= 1 if range.excludes_end?
          count = end_index - start_index + 1
        end
        count = 0 if count < 0

        (start_index..(start_index + count - 1))
      end
    end
  end
end
