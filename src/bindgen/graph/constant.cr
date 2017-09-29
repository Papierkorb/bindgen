module Bindgen
  module Graph
    # A constant value in Crystal and C++.  Stored as CONSTANT in Crystal, and
    # as `static TYPE name = value` in C++.
    class Constant < Node
      alias Type = Bool | UInt8 | UInt16 | UInt32 | UInt64 | Int8 | Int16 | Int32 | Int64 | String | Float32 | Float64

      # The value
      getter value : Type

      def initialize(@value, name, parent)
        super(name, parent)
      end

      # Constants are constant.
      def constant?
        true
      end
    end
  end
end
