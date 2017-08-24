require "spec"
require "../src/bindgen_lib"

def create_type_database : Bindgen::TypeDatabase
  db = Bindgen::TypeDatabase.new(Bindgen::TypeDatabase::Configuration.new)

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
