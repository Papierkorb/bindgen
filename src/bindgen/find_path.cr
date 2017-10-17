require "./find_path/checker"
require "./find_path/*"

module Bindgen
  # Finds paths to files and directories, per user-configuration.  Used to find
  # dependencies of user projects in a somewhat portable fashion.
  #
  # By default this class modifies `ENV` directly.
  class FindPath
    # Pure multi-line option.  Crystal by defaults combines multi-line with the
    # dot-all option, which we don't want.
    MULTILINE_OPTION = Regex::Options.from_value(2)

    {% if flag?(:windows) %}
      PATH_SEPARATOR = ';'
    {% else %}
      PATH_SEPARATOR = ':'
    {% end %}

    # Root path of the project.
    getter root : String

    # Target variables hash.  Will be read from and written to.
    getter variables : Hash(String, String) | ENV.class

    def initialize(@root : String, @variables = ENV)
    end

    # Finds all paths of *config*, and adds missing ones to `#variables`.
    # Returns a list of all encountered errors.
    def find_all!(config : Configuration) : Array(Error)
      find_all(config) do |key, value|
        @variables[key] = value
      end
    end

    # Finds all paths of *config*, yielding for each successful find.
    # Unsuccessful matches are collected into an `Error` array and returned
    # afterwards.
    def find_all(config : Configuration) : Array(Error)
      errors = [ ] of Error

      config.each do |name, single|
        next if has_value?(name)

        if result = find(single)
          yield(name, result)
        else
          errors << Error.new(name, single)
        end
      end

      errors
    end

    # Finds a path for *config*.  On success, returns the path as string.
    # Returns `nil` on error.
    def find(config : PathConfig) : String?
      search_paths = get_search_paths(config)
      checkers = config.checks.map do |check_config|
        Checker.create(check_config, !config.kind.directory?)
      end

      finder = create_match_finder(search_paths, config, checkers)
      collector = MatchCollector.new
      collector.collect(finder)
    end

    # Returns a new `MatchFinder` decided by *config*.
    def create_match_finder(search_paths, config, checkers)
      finder = MatchFinder.new(self, search_paths, config, checkers)

      if version_check = config.version
        VersionedMatchFinder.new(finder, version_check)
      else
        finder
      end
    end


    # Returns the list of search paths, if any
    private def get_search_paths(config) : Array(String)?
      paths = config.search_paths

      if paths.nil?
        if config.kind.executable?
          paths = [ ENV["PATH"] ]
        else
          paths = [ ] of String
        end
      end

      paths.flat_map do |path| # Expand:Paths;Like:This
        expanded = Util.template(path, replacement: @root)
        expanded.split(PATH_SEPARATOR)
      end.reject(&.empty?)
    end

    # Checks if a key for *name* exists and is non-empty.
    private def has_value?(name) : Bool
      value = @variables[name]?

      if value.nil? || value.empty?
        false
      else
        true
      end
    end
  end
end
