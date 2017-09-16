require "./graph/node"
require "./graph/container"
require "./graph/visitor"
require "./graph/*"

module Bindgen
  # The graph is a central module: Its classes are used to represent the final
  # wrappers for all platforms (C++, Crystal, ...) in memory.  The root node is
  # filled using `Graph::Builder`, travels through the `Processor`s, and finally
  # into the `Generator`s.
  module Graph
    # Name of `lib Binding`.  Stores the `fun` declarations.
    LIB_BINDING = "Binding"
  end
end
