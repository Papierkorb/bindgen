module Bindgen
  class FindPath
    # Checker for a `AnyOfCheck`.
    class AnyOfChecker < Checker
      # Child checkers
      @children : Array(Checker)

      def initialize(@config : AnyOfCheck, @is_file : Bool)
        @children = @config.any_of.map do |child|
          Checker.create(child, @is_file)
        end
      end

      # Checks *path* against all child checkers.
      def check(path : String) : Bool
        @children.any?(&.check(path))
      end
    end
  end
end
