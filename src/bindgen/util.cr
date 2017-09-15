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

    # Templates the string *haystack*, replacing occurences of `%` with
    # *replacement*.  If *replacement* is `nil`, this behaviour is disabled.
    #
    # The user can also access environment variables using the syntax `{NAME}`,
    # with `NAME` being the variable name.  A default fallback, in case the
    # `NAME` is unset, can be provided through a pipe symbol: `{NAME|default}`.
    #
    # It's possible to fall back to the character expansion: `{NAME|%}`
    def self.template(haystack : String, replacement : String? = nil, env = ENV)
      haystack.gsub(/(%)|{([^}|]+)(?:\|([^}]+))?}/) do |_, match|
        expansion = match[1]?
        env_var = match[2]?
        alternative = match[3]?

        if expansion && replacement != nil # Support `%` expansion
          replacement
        elsif env_var && env.responds_to?(:[]?) # Support `{ENV}` expansion
          if alternative == '%' # Support `{DOESNT_EXIST|%}`
            alternative = replacement
          elsif alternative.try(&.includes?('%'))
            # Support `{DOESNT_EXIST|Foo % Bar}`
            alternative = template(alternative.not_nil!, replacement, env: false)
          end

          primary = env[env_var]?
          primary || alternative
        else # No expansion found and env expansion is disabled.
          match[0]
        end
      end
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
