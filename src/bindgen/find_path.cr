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
      checkers = config.checks.map do |check_config|
        Checker.create(check_config, !config.kind.directory?)
      end

      if version_check = config.version
        find_versioned(config, checkers, version_check)
      else
        find_unversioned(config, checkers)
      end
    end

    # Returns the best candidate that satisfies all *checkers*
    private def find_versioned(config, checkers, version_check) : String?
      version_checker = VersionChecker.new(version_check)

      find_each_candidate(config, checkers) do |path|
        version_checker.check(path)
      end

      version_checker.best_candidate
    end

    # Returns the first candidate that satisfies all *checkers*
    private def find_unversioned(config, checkers) : String?
      find_each_candidate(config, checkers) do |path|
        return path
      end
    end

    # Yields each path candidate that satisfies all *checkers*
    private def find_each_candidate(config, checkers) : Nil
      config.try.each do |try|
        if found = run_path_try(try, config.kind, checkers)
          yield found
        end
      end

      nil # Not found
    end

    # Tries to match *path* of type *kind* using *checkers*.
    private def run_path_try(path : String, kind, checkers) : String?
      pattern = Util.template(path, @root, env: @variables)

      # Band aid for https://github.com/crystal-lang/crystal/issues/5118
      # TODO: Remove once #5118 is fixed.
      candidates = Dir[pattern]
      if candidates.empty?
        # BUG: This still breaks for `/foo/*/..`
        candidates = [ pattern ]
      end

      candidates.find do |candidate|
        run_path_checkers(candidate, kind, checkers)
      end
    end

    # ditto
    private def run_path_try(shell : ShellTry, kind, checkers) : String?
      if path = run_shell_try(shell)
        run_path_checkers(path, kind, checkers)
      end
    end

    # Tests if *path* matches *kind* and all *checkers*.  Returns *path* on
    # success, or `nil` otherwise.
    private def run_path_checkers(path : String, kind, checkers) : String?
      if kind.exists?(path) && checkers.all?(&.check(path))
        path
      end
    end

    # Helper for `#run_path_try`.
    private def run_shell_try(shell : ShellTry) : String?
      command = Util.template(shell.shell, @root, env: @variables)

      output = `#{command}`
      return nil unless $?.success?

      if rx = shell.regex
        regex_capture(rx, output)
      else
        empty_is_nil(output.lines.first)
      end
    end

    # Tries to match *rx* to *data*, returning the first or zeroth capture group
    # on a successful match.  An empty capture is treated as not matching.
    private def regex_capture(rx : String, data : String) : String?
      regex = Regex.new(rx, MULTILINE_OPTION)
      match = regex.match(data)

      if match
        found = match[1]? || match[0]
        empty_is_nil(found.strip)
      end
    end

    # Returns *string* only if it's not empty nor nil.
    private def empty_is_nil(string) : String?
      if string.nil? || string.empty?
        nil
      else
        string
      end
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
