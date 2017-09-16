module Bindgen
  module Graph
    # An `enum` in Crystal and C++.
    class Enum < Node
      # The original enum
      getter origin : Parser::Enum

      def initialize(@origin, name, parent)
        super(name, parent)
      end
    end
  end
end
