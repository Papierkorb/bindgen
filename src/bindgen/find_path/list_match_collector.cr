module Bindgen
  class FindPath
    # Collects all found candidates from a given match finder, formatting them
    # per user configuration.
    struct ListMatchCollector
      def initialize(@config : ListConfig)
      end

      # Returns the first match *finder* returns.  Returns `nil` if nothing was
      # found.
      def collect(finder : Enumerable(String)) : String?
        candidates = [ ] of String
        finder.each{|x| candidates << x}

        if candidates.empty?
          nil
        else
          format(candidates)
        end
      end

      # Formats the non-empty list of *candidates* into a `String`.
      def format(candidates) : String
        candidates.map{|x| Util.template(@config.template, x)}.join(@config.separator)
      end
    end
  end
end
