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

        # Only used if mapping as enum:  C++ mapping type
        type: {
          type: String,
          default: "int",
        },

        # Only used if mapping as enum:  Treat as flags enum?
        flags: {
          type: Bool,
          default: false,
        },
      )
    end

    # Configuration for a function-class wrapper, see `Function#wrapper`
    class FunctionClass
      YAML.mapping(
        # Backing structure
        structure: String,

        # Crystal type to inherit from
        inherit_from: {
          type: String,
          nilable: true,
        },

        # Constructor function names
        constructors: Array(String),

        # Destructor function name
        destructor: {
          type: String,
          nilable: true,
        },
      )
    end

    # Configuration for function wrapping
    class Function
      YAML.mapping(
        # Mapping name of the function
        name: {
          type: String,
          nilable: true,
        },

        # Qualified name of the destination module/class
        destination: String,

        # Fully crystalize method names?
        crystalize_names: {
          type: Bool,
          nilable: true, # Default depends on `#wrapper` being (not) set
          getter: false,
        },

        # `class:` in the YAML!
        wrapper: {
          key: "class",
          type: FunctionClass,
          nilable: true,
        }
      )

      def initialize(@destination, @name = nil, @wrapper = nil)
      end

      # Shall method names be fully crystalized?
      def crystalize_names? : Bool
        rewrite = @crystalize_names
        if rewrite.nil? # Default to true for class mappings
          @wrapper != nil
        else
          rewrite
        end
      end
    end

    # Converter to accept `Hash(String, String | Function)` and turn it into
    # `Hash(String, Function)`
    module FunctionConverter
      def self.from_yaml(pull)
        hsh = Hash(String, String | Function).new(pull)

        hsh.map do |key, value|
          if value.is_a?(String)
            { key, Function.new(value) }
          else
            { key, value }
          end
        end.to_h
      end
    end

    YAML.mapping(
      # Target Crystal module
      module: String,

      # Cookbook to use for templates
      cookbook: {
        type: String,
        default: "boehmgc-cpp", # See `Cpp::Cookbook.create_by_name`
      },

      # Used processors
      processors: {
        type: Array(String),
        default: Processor::DEFAULT_CHAIN,
      },

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

      # Which functions to wrap
      functions: {
        type: Hash(String, Function),
        default: Hash(String, Function).new,
        converter: FunctionConverter,
      },

      # Which templates to instantiate
      containers: {
        type: Array(Container),
        default: Array(Container).new,
      },

      # Type database configuration
      types: {
        type: TypeDatabase::Configuration,
        default: TypeDatabase::Configuration.new,
      },

      # Parser configuration
      parser: Parser::Configuration,
    )
  end
end
