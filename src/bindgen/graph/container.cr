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

      # Finds a `PlatformSpecific` for *platform*.  If none found, creates one.
      def platform_specific(platform : Platform | Platforms)
        node = platform_specific?(platform)

        if node.nil?
          node = PlatformSpecific.new(platform: platform, parent: self)
        end

        node
      end

      # Finds a `PlatformSpecific` for *platform*.  Returns `nil` if not found.
      def platform_specific?(platform : Platform | Platforms)
        platform = platform.as_flag

        @nodes.each do |node|
          next unless node.is_a?(Graph::PlatformSpecific)
          return node if node.platforms == platform
        end

        nil # Not found
      end
    end
  end
end
