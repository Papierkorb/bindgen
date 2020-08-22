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

      protected def initialize(*, @parts, @global = false)
      end

      # Returns the `Path` with the parts in *range*.  The new `Path` is global
      # only if it includes the first part of this `Path` and this `Path` is
      # also global.
      def [](range : Range) : Path
        range = normalize_range(range)
        Path.new(parts: @parts[range], global: global? && range.includes?(0))
      end

      # Returns the `Path` excluding the last part in `#nodes`, thus pointing
      # to the parent of this path.  Returns a global path if this path is also
      # global.  Raises if this is an empty path.
      def parent : Path
        raise IndexError.new("parent called on empty path") if empty?
        Path.new(parts: @parts[0..-2], global: global?)
      end

      # Returns the local `Path` with only the last part in `#nodes`, thus
      # pointing at the child in `#parent`.  Raises if this is an empty path.
      def last : Path
        raise IndexError.new("last called on empty path") if empty?
        Path.new(parts: @parts[-1..-1], global: false)
      end

      # Returns the last part of this path.  Raises if this is an empty path.
      def last_part : String
        raise IndexError.new("last_part called on empty path") if empty?
        @parts.last
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
          Path.new(parts: target.full_path.map(&.name), global: true)
        else # Self-path lookup on the root.
          Path.new(parts: [] of String, global: true)
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
          new(parts: parts, global: global || false)
        end
      end

      # :ditto:
      def self.from(path : Enumerable(String)) : Path
        parts = path.to_a
        if global = parts.first?.try(&.empty?)
          parts.shift
        end
        new(parts: parts, global: global || false)
      end

      # Returns a self-referencing path.
      def self.self_path : Path
        new(parts: [] of String, global: false)
      end

      # Returns a path that refers to the global root.
      def self.global_root : Path
        new(parts: [] of String, global: true)
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
          new(parts: [wants.name], global: false) # Locally qualified name suffices
        else
          wants_path = wants.full_path
          common, index = last_common(node.full_path, wants_path)

          if common            # We have a common ancestor node
            if common == wants # *node* is inside *wants*
              new(parts: [wants.name], global: false)
            else # !!
              new(parts: wants_path[(index + 1)..-1].map(&.name), global: false)
            end
          else # No common parts in the path.  Fall back to using the full path.
            new(parts: wants_path.map(&.name), global: false)
          end
        end
      end

      # Returns the global path to *node*.
      def self.global(node : Node) : Path
        new(parts: node.full_path.map(&.name), global: true)
      end

      # Does a local look-up starting at *base* for *path*.  The look-up will
      # begin in *base* itself.  If not found, it'll try to find the path by
      # going up to the parent(s).
      #
      # If the *path* starts with `::` (An empty element), the look-up will
      # always start at the global scope.  If `::` is given, the root node
      # is returned.  Otherwise, the first part of the path must be the name
      # of the root node: `::RootNameHere::And::So::On` instead of
      # `::And::So::On`.
      #
      # If not found, returns `nil`.  This method does *not* raise.
      def lookup(base : Node) : Node?
        if global?
          root = base.find_root

          if empty?
            root
          elsif @parts.first == root.name # Make sure we go into our namespace
            try_lookup(root, @parts[1..-1]) # Skip first element
          end
        else
          return base if empty? # Handle self lookup.

          root = base.find_root

          # Try lookup of the path, going up to the parent once if not found.
          while base
            found = try_lookup(base, @parts)
            return found if found
            base = base.parent
          end

          # One last try: Support a local-"global"-path like `Qt::Object`.
          if @parts.first == root.name
            return try_lookup(root, @parts[1..-1])
          end
        end
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
