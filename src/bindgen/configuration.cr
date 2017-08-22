module Bindgen
  # Configuration as read from the `.yml` file passed to **bindgen** as
  # program parameter.
  class Configuration

    # The `output:` sub-section of `Configuration`.
    class Output
      YAML.mapping(
        # Where to write the C++ wrapper code
        cpp: String,

        # Where to write the Crystal code
        crystal: String,

        # Code to include in the generated CPP code at the top
        cpp_preamble: {
          type: String,
          nilable: true,
        },

        # Command to run in the cpp output directory to build the C/C++ binding
        # library.
        cpp_build: {
          type: String,
          nilable: true,
        }
      )
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
        instantiations: Array(Array(String)),

        # Method to access an element at an index.
        access_method: { type: String, default: "at" },

        # Method to add an element at the end.
        push_method: { type: String, default: "push_back" },

        # Method telling the current count of elements.
        size_method: { type: String, default: "size" },
      )
    end

    YAML.mapping(
      # Target Crystal module
      module: String,

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

      # Which templates to instantiate
      containers: {
        type: Array(Container),
        default: Array(Container).new,
      },

      # Where to write the output
      output: Output,

      # Type database configuration
      types: TypeDatabase::Configuration,

      # Parser configuration
      parser: Parser::Configuration,
    )
  end
end
