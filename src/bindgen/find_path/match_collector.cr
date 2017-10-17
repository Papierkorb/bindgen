module Bindgen
  class FindPath
    # Collects the found candidate from a given match finder.
    struct MatchCollector
      # Returns the first match *finder* returns.  Returns `nil` if nothing was
      # found.
      def collect(finder) : String?
        finder.each do |match|
          return match
        end

        nil # No candidate matched.
      end
    end
  end
end
