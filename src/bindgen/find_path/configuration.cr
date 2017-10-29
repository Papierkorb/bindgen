module Bindgen
  class FindPath
    alias Configuration = Hash(String, PathConfig)

    # Converter to read `Array(String | ShellTry)`.
    module TryListConverter
      def self.from_yaml(pull)
        ary = [] of String | ShellTry

        pull.read_sequence do
          while !pull.kind.sequence_end?
            if pull.kind.scalar?
              ary << String.new(pull)
            else
              ary << ShellTry.new(pull)
            end
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

    # A path check testing using multiple inner checkers.
    class AnyOfCheck
      YAML.mapping(
        # Inner checkers
        any_of: Array(PathCheck | ShellCheck),
      )

      def initialize(@any_of)
      end
    end

    # A path check testing the version of a path or program.
    class VersionCheck
      enum Prefer
        Highest
        Lowest
      end

      enum Fallback
        Fail
        Accept
        Prefer
      end

      YAML.mapping(
        # Min version string
        min: {
          type: String,
          nilable: true,
        },

        # Max version string
        max: {
          type: String,
          nilable: true,
        },

        # Variable to store the detected version string in
        variable: {
          type: String,
          nilable: true,
        },

        # Which version to prefer
        prefer: {
          type: Prefer,
          default: Prefer::Highest,
        },

        # Fallback behaviour if the regex fails.
        fallback: {
          type: Fallback,
          default: Fallback::Fail,
        },

        # Regular expression to grab it from the name
        regex: {
          type: String,
          default: "-([0-9.]+)$", # Debian-style
        },

        # Custom command to run to figure out the version
        command: {
          type: String,
          nilable: true,
        }
      )

      def initialize(
        @min = nil, @max = nil, @prefer = Prefer::Highest,
        @fallback = Fallback::Fail, @regex = "-([0-9.]+)$", @command = nil
      )
      end
    end

    # Configuration for `PathConfig#list`.
    class ListConfig
      YAML.mapping(
        # Element separator
        separator: {
          type: String,
          default: FindPath::PATH_SEPARATOR.to_s,
        },

        # Element template
        template: {
          type: String,
        },
      )

      def initialize(@template, @separator = FindPath::PATH_SEPARATOR.to_s)
      end

      def self.default
        new(template: "%")
      end
    end

    # Converts a `Bool | ListConfig` into a `ListConfig | Nil`.
    module ListConfigConverter
      def self.from_yaml(pull) : ListConfig?
        if pull.kind.scalar? # A bool?
          if Bool.new(pull)
            ListConfig.default
          else
            nil
          end
        else # A full config
          ListConfig.new(pull)
        end
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

        # Search paths for relative try paths
        search_paths: {
          type: Array(String),
          nilable: true,
        },

        # Checks to do
        checks: {
          type: Array(PathCheck | ShellCheck | AnyOfCheck),
          default: Array(PathCheck | ShellCheck | AnyOfCheck).new,
        },

        # Version check to do
        version: {
          type: VersionCheck,
          nilable: true,
        },

        # List functionality
        list: {
          type: ListConfig,
          nilable: true,
          converter: ListConfigConverter,
        }
      )

      def initialize(
        @try, @kind = Kind::Directory, @optional = false, @error_message = nil,
        @checks = [ ] of (PathCheck | ShellCheck)
      )
      end
    end
  end
end
