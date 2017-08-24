require "spec"
require "../src/bindgen_lib"

### Helpers

# Short-hand functions
module Parser
  include Bindgen::Parser

  def self.void_type
    Bindgen::Parser::Type::VOID
  end

  def self.type(cpp_type : String) : Bindgen::Parser::Type
    Bindgen::Parser::Type.parse(cpp_type)
  end

  def self.argument(name : String, cpp_type : String, default = nil, has_default = false) : Bindgen::Parser::Argument
    has_default ||= default != nil # Does it actually have a default?
    Bindgen::Parser::Argument.new(
      name: name,
      type: type(cpp_type),
      hasDefault: has_default,
      value: default,
    )
  end

  def self.method(name : String, class_name : String, result : Bindgen::Parser::Type, arguments : Array(Bindgen::Parser::Argument), type = Bindgen::Parser::Method::Type::MemberMethod)
    args = arguments.map do |arg|
      if arg.is_a?(Tuple)
        Parser.argument(*arg)
      else
        arg
      end
    end

    ret = result.is_a?(String) ? Parser.type(result) : result

    Bindgen::Parser::Method.new(
      type: type,
      access: Bindgen::Parser::AccessSpecifier::Public,
      name: name,
      className: class_name,
      arguments: args,
      returnType: ret,
      firstDefaultArgument: args.index(&.has_default?),
    )
  end

  def self.method(name : String, class_name : String, result : Bindgen::Parser::Type, type = Bindgen::Parser::Method::Type::MemberMethod)
    method(name, class_name, result, [ ] of Bindgen::Parser::Argument, type)
  end
end

def create_type_database : Bindgen::TypeDatabase
  config_data = File.read("#{__DIR__}/type_database_fixture.yml")
  config = Bindgen::TypeDatabase::Configuration.from_yaml config_data
  db = Bindgen::TypeDatabase.new(config)

  db.enums["CppWrappedEnum"] = Bindgen::Parser::Enum.new(
    name: "CppWrappedEnum",
    values: { "One" => 1i64, "Two" => 2i64, "Three" => 3i64 },
    isFlags: false,
  )

  db.enums["CppWrappedFlags"] = Bindgen::Parser::Enum.new(
    name: "CppWrappedFlags",
    values: { "One" => 1i64, "Two" => 2i64, "Four" => 4i64 },
    isFlags: true,
  )

  enum_kind = Bindgen::Parser::Type::Kind::Enum
  db.add_sparse_type "CppWrappedEnum", "CrWrappedEnum", enum_kind
  db.add_sparse_type "CppWrappedFlags", "CrWrappedFlags", enum_kind

  db
end
