module Bindgen
  module Graph
    # This node acts as gate for platform-specific structures.  It's not
    # represented in generated output by itself.
    #
    # See also `Container#platform_specific`.
    class PlatformSpecific < Container
      # The target platform
      getter platform : Platform

      def initialize(@platform, parent = nil)
        super("Specific to #{@platform}", parent)
      end
    end
  end
end
