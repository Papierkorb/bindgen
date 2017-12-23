module Bindgen
  # Classes to read YAML configuration data.
  #
  # For documentation on
  # * the YAML features, see `Parser`
  # * default condition variables, see `Variables`
  #
  # These should be mirrored in the `README.md` file.
  module ConfigReader
    alias VariableHash = Hash(String, String)

    # Constructs a *klass* instance using the YAML data at *content*.
    # *path* points to the processed YAML file, and is used to find external
    # dependency files.  Additional condition *variables* can be passed if
    # required.
    #
    # See also `.from_file`.
    def self.from_yaml(klass : Class, content : String | IO, path : String, variables : VariableHash? = nil)
      vars = Variables.build(variables)
      evaluator = ConditionEvaluator.new(vars)
      parser = Parser.new(content, evaluator, path)
      klass.new(YAML::ParseContext.new, parser.parse.nodes.first)
    end

    # Same as `.from_yaml`, but reads the file at *path* directly.
    def self.from_file(klass : Class, path : String, variables : VariableHash? = nil)
      from_yaml(klass, File.read(path), path, variables)
    end
  end
end
