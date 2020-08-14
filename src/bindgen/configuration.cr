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
          when "true"  then return true
          when "false" then return false
          else
            # its a string
          end
        end

        String.new(ctx, node)
      end
    end

    # Reads the table of instance variable configurations.  Additionally accepts
    # `true` (use default settings) and `false` (ignore all members).
    module InstanceVariablesConverter
      private alias ValueType = TypeDatabase::InstanceVariableConfig::Collection

      def self.from_yaml(ctx : YAML::ParseContext, node : YAML::Nodes::Node) : ValueType
        if node.is_a?(YAML::Nodes::Scalar)
          case node.value
          when "true"
            ValueType.new
          when "false"
            { /.*/ => TypeDatabase::InstanceVariableConfig.new ignore: true }
          else
            node.raise "Expected Bool or Hash for instance_variables"
          end
        else
          str_table = Hash(String, TypeDatabase::InstanceVariableConfig).new(ctx, node)
          str_table.transform_keys(&->Regex.new(String))
        end
      end
    end

    # Configuration of a generator, as given as value in `generators:`
    class Generator
      include YAML::Serializable

      # Output file path of this generator.  Can be a template string: If a
      # percent-sign is found in it, the generator will split the output data
      # after each logical unit.  A logical unit is generator-specific, though
      # it's usually something like a class.
      property output : String

      # Custom preamble.  Will be added to each output file right at the
      # beginning, before anything else.
      property preamble : String? = nil

      # If set, the command (including any set arguments) will be executed
      # using `#system`.  Use this to build the output of a generator.  If
      # the ran command fails (That means its exit code is not zero), then
      # bindgen fails immediately, passing on the same exit code.
      property build : String? = nil

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
      include YAML::Serializable

      # Class name of the template type
      property class : String

      # Type of the container
      property type : Type

      # List of instantiations to create.
      property instantiations : Array(Array(String)) = [] of Array(String)

      # Method to access an element at an index.
      property access_method : String = "at"

      # Method to add an element at the end.
      property push_method : String = "push_back"

      # Method telling the current count of elements.
      property size_method : String = "size"
    end

    # Configuration for enum mapping
    class Enum
      include YAML::Serializable

      # Path of the enumeration type in Crystal
      property destination : String

      # Common prefix detection of enums
      @[YAML::Field(converter: Bindgen::Configuration::StringOrBool)]
      property prefix : String | Bool = false

      # Forces a specific `@[Flags]` setting
      property flags : Bindgen::Util::Tribool = Bindgen::Util::Tribool.unset

      # Camelcase translation
      property camelcase : Bool = true

      def initialize(@destination, @prefix = false, @flags = Bindgen::Util::Tribool.unset, @camelcase = true)
      end
    end

    # Configuration for a macro
    class Macro
      enum MapAs
        Enum
        Constant
      end

      include YAML::Serializable

      # How to map the macro
      property map_as : MapAs

      # The name mapping.  Can be left out.
      property name : String? = nil

      # Destination Crystal-path
      property destination : String

      # Only used if mapping as enum:  C++ mapping type
      property type : String? = nil

      # Only used if mapping as enum:  Treat as flags enum?
      property flags : Bool = false
    end

    # Configuration for a function-class wrapper, see `Function#wrapper`
    class FunctionClass
      include YAML::Serializable

      # Backing structure
      property structure : String

      # Crystal type to inherit from
      property inherit_from : String? = nil

      # Constructor function names
      property constructors : Array(String)

      # Destructor function name
      property destructor : String? = nil
    end

    # Configuration for function wrapping
    class Function
      include YAML::Serializable

      # Mapping name of the function
      property name : String? = nil

      # Qualified name of the destination module/class
      property destination : String

      # Fully crystalize method names?
      property crystalize_names : Bindgen::Util::Tribool = Bindgen::Util::Tribool.unset

      # `class:` in the YAML!
      @[YAML::Field(key: "class")]
      property wrapper : FunctionClass? = nil

      def initialize(@destination, @name = nil, @wrapper = nil, @crystalize_names = Bindgen::Util::Tribool.unset)
      end

      # Shall method names be fully crystalized?
      def crystalize_names? : Bool
        @crystalize_names.true?(@wrapper != nil)
      end
    end

    include YAML::Serializable

    # Target Crystal module
    property module : String

    # Cookbook to use for templates
    property cookbook : String = "boehmgc-cpp" # See `Cpp::Cookbook.create_by_name`

    # Used processors
    property processors : Array(String) = Bindgen::Processor::DEFAULT_CHAIN

    # Used generators
    property generators : Hash(String, Bindgen::Configuration::Generator)

    # What to put into `@[Link(ldflags: "x")]`
    property library : String? = nil

    # Which enums to wrap
    @[YAML::Field(converter: Bindgen::Configuration::GenericConverter(Bindgen::Configuration::Enum))]
    property enums : Hash(String, Bindgen::Configuration::Enum) = Hash(String, Bindgen::Configuration::Enum).new

    # Which classes to wrap
    property classes : Hash(String, String) = Hash(String, String).new

    # Which macros to wrap
    property macros : Hash(String, Bindgen::Configuration::Macro) = Hash(String, Bindgen::Configuration::Macro).new

    # Which functions to wrap
    @[YAML::Field(converter: Bindgen::Configuration::GenericConverter(Bindgen::Configuration::Function))]
    property functions : Hash(String, Bindgen::Configuration::Function) = Hash(String, Bindgen::Configuration::Function).new

    # Which templates to instantiate
    property containers : Array(Bindgen::Configuration::Container) = Array(Bindgen::Configuration::Container).new

    # Type database configuration
    property types : Bindgen::TypeDatabase::Configuration = Bindgen::TypeDatabase::Configuration.new

    # Parser configuration
    property parser : Bindgen::Parser::Configuration

    # Find path configuration
    property find_paths : Bindgen::FindPath::Configuration? = nil
  end
end
