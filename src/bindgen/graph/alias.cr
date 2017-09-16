module Bindgen
  module Graph
    # An `alias` in Crystal and a `typedef` in C++.  The `#name` is the name of
    # the alias itself (The "new" name).  `#origin` points to the original type.
    class Alias < Node
      # The origin type.
      getter origin : Call::Result

      def initialize(@origin, name, parent)
        super(name, parent)
      end
    end
  end
end
