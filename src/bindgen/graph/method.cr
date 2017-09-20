module Bindgen
  module Graph
    # A method, and its calls.  The `#calls` will be populated later on by
    # processors.
    class Method < Node
      # If this tag is set, it means this method is a `#initialize(unwrap: )`.
      # The value is left empty.
      UNWRAP_INITIALIZE_TAG = "UNWRAP_INITIALIZE_TAG"

      # `Parser::Method` this method node is based on.
      getter origin : Parser::Method

      # Calls for the various `Generator`s
      getter calls = { } of Platform => Call

      def initialize(@origin, name, parent)
        super(name, parent)
      end

      # Returns the class containing this method.
      def parent_class : Graph::Class?
        p = @parent

        while p
          return p if p.is_a?(Graph::Class)
          p = p.parent
        end

        nil
      end

      # Returns a dot (`.`) if the origin method is static.  Returns a number
      # sign (`#`) otherwise.
      def crystal_prefix : String
        if @origin.static_method?
          "."
        else
          "#"
        end
      end

      # A method is not a constant in Crystal.
      def constant? : Bool
        false
      end

      delegate mangled_name, to: @origin
    end
  end
end
