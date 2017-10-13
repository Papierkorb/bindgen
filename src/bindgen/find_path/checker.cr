module Bindgen
  class FindPath
    # Path checker base class.
    abstract class Checker
      # Creates the correct checker for the *config*.
      def self.create(config, is_file) : Checker
        case config
        when PathCheck then PathChecker.new(config, is_file)
        when ShellCheck then ShellChecker.new(config)
        else raise "BUG: Unreachable!"
        end
      end

      # Checks if *path* is acceptable.  Returns `true` if so, `false`
      # otherwise.
      abstract def check(path : String) : Bool
    end
  end
end
