module Bindgen
  module Graph
    # This node acts as gate for platform-specific structures.  It's not
    # represented in generated output by itself.
    #
    # See also `Container#platform_specific`.
    class PlatformSpecific < Container
      # The target platform
      getter platforms : Platforms

      def initialize(platform : Platform | Platforms, parent = nil)
        @platforms = platform.as_flag
        super("Specific to #{@platforms}", parent)
      end
    end
  end
end
