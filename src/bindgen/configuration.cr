module Bindgen
  # Configuration as read from the `.yml` file passed to **bindgen** as
  # program parameter.
  class Configuration
    # Converter to accept `Hash(String, String | T)` and turn it into
    # `Hash(String, T)`
    module GenericConverter(T)
      def self.from_yaml(ctx : YAML::ParseContext, value_node : YAML::Nodes::Node) : Hash(String, T)
        hsh = Hash(String, T).new

        Hash(String, String | T).new(ctx, value_node) do |key, value|
          value = T.new(value) if value.is_a?(String)
          hsh[key] = value
        end

        hsh
      end
    end

    # Reads a `(String | Bool)` from a YAML pull parser without breaking.
    module StringOrBool
      def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : String | Bool
        if node.is_a?(YAML::Nodes::Scalar)
          case node.value
          when "true" then return true
          when "false" then return false
          end
        end

        String.new(ctx, node)
      end
    end

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

    # Configuration for enum mapping
    class Enum
      YAML.mapping(
        # Path of the enumeration type in Crystal
        destination: String,

        # Common prefix detection of enums
        prefix: {
          type: String | Bool,
          default: false,
          converter: StringOrBool,
        },

        # Forces a specific `@[Flags]` setting
        flags: {
          type: Util::Tribool,
          default: Util::Tribool.unset,
        },

        # Camelcase translation
        camelcase: {
          type: Bool,
          default: true
        },
      )

      def initialize(@destination, @prefix = false, @flags = Util::Tribool.unset, @camelcase = true)
      end
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
          nilable: true,
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
          type: Util::Tribool,
          default: Util::Tribool.unset, # Default depends on `#wrapper` being set
          getter: false,
        },

        # `class:` in the YAML!
        wrapper: {
          key: "class",
          type: FunctionClass,
          nilable: true,
        }
      )

      def initialize(@destination, @name = nil, @wrapper = nil, @crystalize_names = Util::Tribool.unset)
      end

      # Shall method names be fully crystalized?
      def crystalize_names? : Bool
        @crystalize_names.true?(@wrapper != nil)
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
        type: Hash(String, Enum),
        default: Hash(String, Enum).new,
        converter: GenericConverter(Enum),
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
        converter: GenericConverter(Function),
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

      # Find path configuration
      find_paths: {
        type: FindPath::Configuration,
        nilable: true,
      },
    )
  end
end
