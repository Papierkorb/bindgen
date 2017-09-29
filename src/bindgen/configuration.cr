module Bindgen
  # Configuration as read from the `.yml` file passed to **bindgen** as
  # program parameter.
  class Configuration

    # Configuration of a generator, as given as value in `generators:`
    class Generator
      YAML.mapping(
        # Output file path of this generator.  Can be a template string: If a
        # percent-sign is found in it, the generator will split the output data
        # after each logical unit.  A logical unit is generator-specific, though
        # it's usually something like a class.
        output: String,

        # Custom preamble.  Will be added to each output file right at the
        # beginning, before anything else.
        preamble: {
          type: String,
          nilable: true,
        },

        # If set, the command (including any set arguments) will be executed
        # using `#system`.  Use this to build the output of a generator.  If
        # the ran command fails (That means its exit code is not zero), then
        # bindgen fails immediately, passing on the same exit code.
        build: {
          type: String,
          nilable: true,
        },
      )

      def initialize(@output, @preamble, @build)
      end

      # Builds an empty, dummy generator configuration
      def self.dummy
        Generator.new(
          preamble: nil,
          build: nil,
          output: "", # Will not be used.
        )
      end
    end

    # Configuration of template container types and their instantiations.
    class Container
      enum Type
        Sequential
        Associative
      end

      YAML.mapping(
        # Class name of the template type
        class: String,

        # Type of the container
        type: Type,

        # List of instantiations to create.
        instantiations: {
          type: Array(Array(String)),
          default: [ ] of Array(String),
        },

        # Method to access an element at an index.
        access_method: { type: String, default: "at" },

        # Method to add an element at the end.
        push_method: { type: String, default: "push_back" },

        # Method telling the current count of elements.
        size_method: { type: String, default: "size" },
      )
    end

    # Configuration for a macro
    class Macro
      enum MapAs
        Enum
        Constant
      end

      YAML.mapping(
        # How to map the macro
        map_as: MapAs,

        # The name mapping.  Can be left out.
        name: {
          type: String,
          nilable: true,
        },

        # Destination Crystal-path
        destination: String,
      )
    end

    YAML.mapping(
      # Target Crystal module
      module: String, # TODO: Keep this?  Or move into `Generator`?

      # Used processors
      processors: Array(String),

      # Used generators
      generators: Hash(String, Generator),

      # What to put into `@[Link(ldflags: "x")]`
      library: {
        type: String,
        nilable: true,
      },

      # Which enums to wrap
      enums: {
        type: Hash(String, String),
        default: Hash(String, String).new,
      },

      # Which classes to wrap
      classes: {
        type: Hash(String, String),
        default: Hash(String, String).new,
      },

      # Which macros to wrap
      macros: {
        type: Hash(String, Macro),
        default: Hash(String, Macro).new,
      },

      # Which templates to instantiate
      containers: {
        type: Array(Container),
        default: Array(Container).new,
      },

      # Type database configuration
      types: TypeDatabase::Configuration,

      # Parser configuration
      parser: Parser::Configuration,
    )
  end
end
