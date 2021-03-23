module Bindgen
  module Graph
    # A `lib union` in Crystal, or a plain `union` in C/C++.
    class CppUnion < Container
      # Variant members in this structure.
      getter fields : Hash(String, Call::Result)

      def initialize(@fields, name, parent)
        super(name, parent)
      end
    end
  end
end
