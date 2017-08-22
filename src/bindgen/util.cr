module Bindgen
  module Util
    # Mimics Rubys `Enumerable#uniq_by`.  Takes a *list*, and makes all values
    # in it unique by yielding all pairs, keeping only those items where the
    # block returned a falsy value.
    #
    # This method is `O(n²)`, prefer `Enumerable#uniq` if possible.
    def self.uniq_by(list : Array)
      result = list.class.new

      list.each do |elem|
        skip = result.any? do |other|
          yield(elem, other)
        end

        result << elem unless skip
      end

      result
    end

    # Templates the string *haystack*, replacing occurences of *char* with
    # *replacement*.  The default *char* is the percent-sign (`%`).
    def self.template(haystack, replacement, char = '%')
      haystack.gsub(char, replacement)
    end

    # Mangles the type name of *full_type_name* for the binding function:
    # * A pointer-star is turned into `X`
    # * A reference-ampersand is turned into `R`
    # * Any non-word character is replaced with `_`
    def self.mangle_type_name(full_type_name : String)
      full_type_name.gsub("*", "X").gsub("&", "R").gsub(/\W/, "_")
    end

    # Mangles a list of type-names into a combined string.
    def self.mangle_type_names(full_type_names : String)
      full_type_names.map{|x| mangle_type_name x}.join("_")
    end
  end
end
