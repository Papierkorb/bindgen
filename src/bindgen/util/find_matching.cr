module Bindgen
  module Util
    # Mix-in providing a `#find_matching` function.  Used by processors.
    module FindMatching(T)
      # Finds all elements in *list*, whose `T#name` matches *regex*.
      private def find_matching(regex : String, list : Enumerable(T)) : Array(Tuple(T, Regex::MatchData))
        rx = /^#{regex}$/

        matching = [ ] of { T, Regex::MatchData }
        list.each do |element|
          if match = rx.match(element.name)
            matching << { element, match }
          end
        end

        matching
      end
    end
  end
end
