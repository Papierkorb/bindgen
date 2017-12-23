module Bindgen
  class FindPath
    # Checker for a `ShellCheck`.
    class ShellChecker < Checker
      def initialize(@config : ShellCheck)
      end

      # Checks *path* by calling out to the configured shell command, expanding
      # *path* into it.  `STDOUT` is hidden, but `STDERR` is shown.  Only
      # succeeds if the command returned exit code `0`.
      def check(path : String) : Bool
        command = Util.template(@config.shell, path)
        Process.run(
          command: command,
          shell: true,
          output: Process::Redirect::Close,
          error: Process::Redirect::Inherit,
        ).success?
      end
    end
  end
end
