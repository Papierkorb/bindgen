module Bindgen
  class FindPath
    # Error type used to store errors.  This is **not** an `Exception`!
    class Error
      # Name of the variable to set
      getter variable : String

      # Configuration used
      getter config : PathConfig

      def initialize(@variable, @config)
      end
    end
  end
end
