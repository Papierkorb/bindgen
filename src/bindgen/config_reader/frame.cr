module Bindgen
  module ConfigReader
    # Condition-test stack frame.  Helper structure for `Parser`.
    class Frame
      # State of the frame
      property state : FrameState

      # Is the current value a mapping key?
      property? key : Bool = false

      # Is this frame embedded?  This means that the `#read_next` will eat this
      # frames `mapping_end`, to make it transparent to the client we actually
      # "merged" a whole mapping into the current mapping.
      property? embedded : Bool = false

      def initialize(@state)
      end
    end
  end
end
