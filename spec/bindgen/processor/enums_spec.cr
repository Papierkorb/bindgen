require "../../spec_helper"

private def lookup(graph, path)
  Bindgen::Graph::Path.from(path).lookup(graph).as(Bindgen::Graph::Enum)
end

describe Bindgen::Processor::Enums do
  config = Bindgen::Configuration.from_yaml <<-YAML
  module: Foo
  generators: { }
  parser: { files: [ "foo.h" ] }

  enums:
    base_module: Normal
    sub_module:
      destination: "Outer::Flags"
    flags_unset_true: FlagsUnsetTrue
    flags_unset_false: FlagsUnsetFalse
    flags_true:
      destination: FlagsTrue
      flags: true
    flags_false:
      destination: FlagsFalse
      flags: false
    prefix_true:
      destination: PrefixTrue
      prefix: true
    prefix_false:
      destination: PrefixFalse
      prefix: false
    prefix_string:
      destination: PrefixString
      prefix: "Flags_"
  YAML

  flags_enum = Bindgen::Parser::Enum.new(
    name: "flags_enum",
    type: "int",
    isFlags: true,
    values: {
      "Flags_One" => 1i64,
      "Flags_Two" => 2i64,
      "Different_Three" => 3i64,
    }
  )

  normal_enum = Bindgen::Parser::Enum.new(
    name: "normal_enum",
    type: "int",
    isFlags: false,
    values: {
      "Normal_One" => 1i64,
      "Normal_Two" => 2i64,
      "Normal_Three" => 3i64,
    }
  )

  db = Bindgen::TypeDatabase.new(Bindgen::TypeDatabase::Configuration.new, "boehmgc-cpp")
  doc = Bindgen::Parser::Document.new(
    enums: {
      "base_module" => normal_enum,
      "sub_module" => flags_enum,
      "flags_unset_true" => flags_enum,
      "flags_unset_false" => normal_enum,
      "flags_true" => normal_enum,
      "flags_false" => flags_enum,
      "prefix_true" => normal_enum,
      "prefix_false" => normal_enum,
      "prefix_string" => flags_enum,
    },
  )

  subject = Bindgen::Processor::Enums.new(config, db)
  graph = Bindgen::Graph::Namespace.new("ROOT")
  subject.process(graph, doc)

  context "destination configuration" do
    it "maps into the base module" do
      node = lookup(graph, "Normal")
      node.origin.should eq(normal_enum)
    end

    it "maps into a sub-module" do
      node = lookup(graph, "Outer::Flags")
      node.origin.should eq(flags_enum)
    end
  end

  context "@[Flags] configuration behaviour" do
    context "flags: unset" do
      it "keeps the setting" do
        lookup(graph, "FlagsUnsetTrue").origin.flags?.should be_true
        lookup(graph, "FlagsUnsetFalse").origin.flags?.should be_false
      end
    end

    context "flags: true" do
      it "forces it to true" do
        lookup(graph, "FlagsTrue").origin.flags?.should be_true
      end
    end

    context "flags: false" do
      it "forces it to false" do
        lookup(graph, "FlagsFalse").origin.flags?.should be_false
      end
    end
  end

  context "prefix configuration behaviour" do
    context "prefix: true" do
      it "removes the common prefix automatically" do
        lookup(graph, "PrefixTrue").origin.values.should eq({
          "One" => 1i64, # Will remove "Normal_"
          "Two" => 2i64,
          "Three" => 3i64,
        })
      end
    end

    context "prefix: false" do
      it "leaves any prefix alone" do
        lookup(graph, "PrefixFalse").origin.values.should eq(normal_enum.values)
      end
    end

    context "prefix: String" do
      it "removes matching prefix only" do
        lookup(graph, "PrefixString").origin.values.should eq({
          "One" => 1i64, # Will remove "Flags_"
          "Two" => 2i64,
          "Different_Three" => 3i64, # Leaves different prefix alone
        })
      end
    end
  end
end
