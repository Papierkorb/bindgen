module Bindgen
  module Graph
    # A `lib` in Crystal.  C++ doesn't have an equivalent for this.
    class Library < Container
      # The linker directive.  If set, the Crystal generator will embed it in
      # `@[Link(ld_flags: "HERE")]`.
      getter ld_flags : String?

      def initialize(@ld_flags, name, parent)
        super(name, parent)
      end
    end
  end
end
