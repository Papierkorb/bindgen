module Bindgen
  class FindPath
    alias Configuration = Hash(String, PathConfig)

    # Converter to read `Array(String | ShellTry)`.
    module TryListConverter
      def self.from_yaml(pull)
        ary = [] of String | ShellTry

        pull.read_sequence do
          if pull.kind.scalar?
            ary << String.new(pull)
          else
            ary << ShellTry.new(pull)
          end
        end

        ary
      end
    end

    # Used in `PathConfig#try` to distinguish a path try from a shell one.
    class ShellTry
      YAML.mapping(
        # The shell command to run
        shell: String,

        # An optional regex to grab the path
        regex: {
          type: String,
          nilable: true,
        }
      )

      def initialize(@shell, @regex = nil)
      end
    end

    # A path check testing a specific path.
    class PathCheck
      YAML.mapping(
        # The sub-path to check for existence.
        path: String,

        # What the path should be
        kind: {
          type: Kind,
          default: Kind::File,
        },

        # Optional: What the file should contain
        contains: {
          type: String,
          nilable: true,
        },

        # Treat the contains as regular expression?
        regex: {
          type: Bool,
          default: false,
        },
      )

      def initialize(@path, @kind = Kind::File, @contains = nil, @regex = false)
      end
    end

    # A path check testing using a custom shell command.
    class ShellCheck
      YAML.mapping(
        # The shell command to run
        shell: String,
      )

      def initialize(@shell)
      end
    end

    # YAML-based configuration.  Used as value for the `#find_paths` option in
    # `Bindgen::Configuration`.
    class PathConfig
      YAML.mapping(
        # Kind of file to find
        kind: {
          type: Kind,
          default: Kind::Directory,
        },

        # Is this match optional?
        optional: {
          type: Bool,
          default: false, # Mandatory by default
        },

        # Optional: An error message if not found
        error_message: {
          type: String,
          nilable: true,
        },

        # Paths to try
        try: {
          type: Array(String | ShellTry),
          converter: TryListConverter,
        },

        # Checks to do
        checks: {
          type: Array(PathCheck | ShellCheck),
          default: Array(PathCheck | ShellCheck).new,
        },
      )

      def initialize(
        @try, @kind = Kind::Directory, @optional = false, @error_message = nil,
        @checks = [ ] of (PathCheck | ShellCheck)
      )
      end
    end
  end
end
