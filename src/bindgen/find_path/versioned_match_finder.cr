module Bindgen
  class FindPath
    # Finds all matches, yielding them in the sorted order going from most to
    # least preferred.
    struct VersionedMatchFinder
      def initialize(@finder : Enumerable(String), @version_check : VersionCheck)
      end

      # Iterates over the set of candidates, yielding each candidate in sorted
      # order.
      def each
        version_checker = VersionChecker.new(@version_check)

        @finder.each do |path|
          version_checker.check(path)
        end

        version_checker.sorted_candidates.each do |candidate|
          yield candidate
        end
      end
    end
  end
end
