module Bindgen
  # Database of type mapping data for wrapper-code generation.  Configuration
  # for common (and built-in) C/C++ types is automatically loaded and added.
  class TypeDatabase

    # Describes different styles of argument passing.
    enum PassBy
      Original # Keep the original type
      Reference # Force a C++ reference
      Pointer # Force a C++ pass-by-pointer
      Value # Force a C++ pass-by-value
    end

    # Configuration of types, used in `Configuration#types` (The `types:` map
    # in YAML).  See `TypeDatabase::Configuration`.
    class TypeConfig
      YAML.mapping(
        # Ignore any and all methods using this type anywhere.
        ignore: {
          type: Bool,
          default: false,
        },

        # Semantics of the type (Kind overwrite)
        kind: {
          type: Parser::Type::Kind,
          default: Parser::Type::Kind::Class,
        },

        # Will copy the definition of the other rule into this one.
        alias_for: {
          type: String,
          nilable: true,
        },

        # The crystal name of this type.
        crystal_type: String?,

        # The C++ type to pass it around.
        cpp_type: String?,

        # The type used in Crystal, but only in the `lib` binding.
        binding_type: String?,

        # Template code ran to turn the real C++ type into the crystal type.
        from_cpp: String?,

        # Template code ran to turn the crystal type into the real C++ type.
        to_cpp: String?,

        # Converter for this type in Crystal.  Takes precedence over the
        # `#to_crystal` and `#from_crystal` fields.
        converter: String?,

        # Template code ran to turn the binding type to Crystal.
        to_crystal: String?,

        # Template code ran to turn the Crystal type for the binding.
        from_crystal: String?,

        # How to pass this type to C++?
        pass_by: {
          type: PassBy,
          default: PassBy::Original,
        },

        # How to pass this type from Crystal?
        wrapper_pass_by: { # Defaults to `@pass_by`
          type: PassBy,
          nilable: true,
        },

        # If sub-classing of this type is allowed, if it's wrapped and has
        # virtual methods.
        sub_class: {
          type: Bool,
          default: true,
        },

        # If the structure (as in, its fields) shall be tried to replicated in Crystal.
        # This doesn't support inheritance!
        copy_structure: {
          type: Bool,
          default: false,
        },

        # Treat this type as built-in type in C++ and Crystal.
        builtin: {
          type: Bool,
          default: false,
        },

        # If to generate a wrapper in Crystal.
        generate_wrapper: {
          type: Bool,
          default: true,
        },

        # If to generate bindings in C++ and Crystal.
        generate_binding: {
          type: Bool,
          default: true,
        },

        # Which methods to filter out.
        ignore_methods: {
          type: Array(String),
          default: [ ] of String,
        }
      )

      def initialize(
        @crystal_type = nil, @cpp_type = nil, @binding_type = nil,
        @from_cpp = nil, @to_cpp = nil, @converter = nil,
        @kind = Parser::Type::Kind::Class, @ignore = false,
        @pass_by = PassBy::Original, @wrapper_pass_by = nil,
        @sub_class = true, @copy_structure = false, @generate_wrapper = true,
        @generate_binding = true, @builtin = false, @ignore_methods = [ ] of String,
      )
      end

      # Shall methods using this type be ignored?
      def ignore? : Bool
        @ignore
      end

      # Type name to use in the Crystal `lib` block.
      def lib_type : String?
        if @copy_structure || @builtin || @kind.enum?
          @binding_type || @crystal_type || @cpp_type
        else
          @binding_type || @cpp_type
        end
      end

      # Type name to use in the Crystal wrapper.
      def wrapper_type : String?
        @crystal_type || @binding_type
      end

      # Pass-by configuration in wrapper code.  Prefers the `#wrapper_pass_by`
      # value, and falls back to `#pass_by`.
      def crystal_pass_by : PassBy
        @wrapper_pass_by || @pass_by
      end
    end

    # Path to the built-in type configuration.  This file defines mappings for
    # most-ish built-in (and other common) types in C++.
    BUILTIN_CONFIG_PATH = "#{__DIR__}/../../builtin_types.yml"

    # Configuration, as used in `Bindgen::Configuration#types`
    alias Configuration = Hash(String, TypeConfig)

    # Helper method to read the built-in type configuration.
    def self.load_builtins : Configuration
       Configuration.from_yaml File.read(BUILTIN_CONFIG_PATH)
    end

    # Registered enumerations.
    getter enums = { } of String => Parser::Enum

    @types : Configuration

    def initialize(config : Configuration, with_builtins = true)
      if with_builtins
        builtins = self.class.load_builtins
        config = builtins.merge(config)
      end

      @types = config.dup
    end

    # Look up *type* in the database.
    def [](type : Parser::Type | String)
      type = type.base_name if type.is_a?(Parser::Type)
      check_for_alias @types[type]
    end

    # Look up *type* in the database.
    def []?(type : Parser::Type | String)
      type = type.base_name if type.is_a?(Parser::Type)
      check_for_alias @types[type]?
    end

    # Look-up an enumeration of name *type*
    def enum?(type : Parser::Type) : Parser::Enum?
      @enums[type.base_name]?
    end

    # Look-up an enumeration of *name*
    def enum?(name : String) : Parser::Enum
      @enums[name]?
    end

    # Adds a type *rules* as *name*.
    def add(name : String, rules : TypeConfig)
      @types[name] = rules
    end

    # Helper, equivalent to calling `#[type]?.try(&.x) || default`
    def try_or(type : Parser::Type | String, default)
      result = check_for_alias(self[type]?).try{|x| yield x}

      if result.nil?
        default
      else
        result
      end
    end

    # Returns the rules for *type*.  If none are found, a new `TypeConfig` is
    # inserted, and returned.
    def get_or_add(type : Parser::Type | String) : TypeConfig
      type = type.base_name if type.is_a?(Parser::Type)

      if rules = @types[type]?
        rules
      else
        rules = TypeConfig.new
        @types[type] = rules
        rules
      end
    end

    # Tries to lookup the fully-qualified type *name* and return its kind.
    # If none found, returns *default*.
    def kind_of(name : String, default = Parser::Type::Kind::Class) : Parser::Type::Kind
      if kind = @types[name]?.try(&.kind)
        kind
      elsif @enums[name]?
        Parser::Type::Kind::Enum
      else
        default
      end
    end

    # Adds a type configuration to the type database.  If a configuration for
    # this type was set by the user, it's updated - *not* replaced!
    def add_sparse_type(cpp_name : String, crystal_name : String?, kind)
      config = @types[cpp_name]?
      new_config = config.nil?

      config ||= TypeConfig.new

      config.kind = kind if new_config
      # config.binding_type ||= crystal_name
      config.cpp_type ||= cpp_name
      config.crystal_type ||= crystal_name if config.generate_wrapper

      @types[cpp_name] = config
    end

    # Checks if *rules* has an `TypeConfig#alias_for` set.  If so, looks up the
    # rules of that aliased name, and returns it.  Otherwise, returns the given
    # *rules*.
    private def check_for_alias(rules)
      if other_name = rules.try(&.alias_for)
        self[other_name]?
      else
        rules
      end
    end
  end
end
