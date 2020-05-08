require "../../spec_helper"

describe Bindgen::Graph::Method do
  int_type = Bindgen::Parser::Type.parse("int")

  member_method = Bindgen::Parser::Method.build(
    type: Parser::Method::Type::MemberMethod,
    name: "some_member",
    class_name: "SomeClass",
    return_type: Bindgen::Parser::Type::VOID,
    arguments: [Bindgen::Parser::Argument.new("some_arg", int_type)],
  )

  static_method = Bindgen::Parser::Method.build(
    type: Parser::Method::Type::StaticMethod,
    name: "some_static",
    class_name: "SomeClass",
    return_type: Bindgen::Parser::Type::VOID,
    arguments: [] of Bindgen::Parser::Argument,
  )

  constructor_method = Bindgen::Parser::Method.build(
    type: Parser::Method::Type::Constructor,
    name: "",
    class_name: "SomeClass",
    return_type: Bindgen::Parser::Type::VOID,
    arguments: [] of Bindgen::Parser::Argument,
  )

  parser_klass = Bindgen::Parser::Class.new(
    name: "Foo",
    methods: [member_method, static_method],
  )

  describe "#parent_class" do
    it "finds the direct parent" do
      klass = Bindgen::Graph::Class.new(parser_klass, "Foo")
      method = Bindgen::Graph::Method.new(member_method, "func", klass)

      method.parent_class.should be(klass)
    end

    it "traverses through platform specifics" do
      klass = Bindgen::Graph::Class.new(parser_klass, "Foo")
      specific = klass.platform_specific(Bindgen::Graph::Platform::Crystal)
      method = Bindgen::Graph::Method.new(member_method, "func", specific)

      method.parent_class.should be(klass)
    end

    it "doesn't traverse non-classes" do
      klass = Bindgen::Graph::Class.new(parser_klass, "Foo")
      mod = Bindgen::Graph::Namespace.new("Bar", klass)
      method = Bindgen::Graph::Method.new(member_method, "func", mod)

      method.parent_class.should be_nil
    end
  end

  describe "#crystal_prefix" do
    context "origin: static method" do
      it "returns '.'" do
        method = Bindgen::Graph::Method.new(static_method, "func")
        method.crystal_prefix.should eq(".")
      end
    end

    context "origin: member method" do
      it "returns '#'" do
        method = Bindgen::Graph::Method.new(member_method, "func")
        method.crystal_prefix.should eq("#")
      end
    end
  end

  describe "#diagnostics_path" do
    it "returns a pretty-printed path" do
      mod = Bindgen::Graph::Namespace.new("Stuff")
      klass = Bindgen::Graph::Class.new(parser_klass, "Foo", mod)
      method = Bindgen::Graph::Method.new(member_method, "func", klass)

      method.diagnostics_path.should eq("Stuff::Foo#func(some_arg)")
    end

    it "masquerades as #initialize on a constructor" do
      mod = Bindgen::Graph::Namespace.new("Stuff")
      klass = Bindgen::Graph::Class.new(parser_klass, "Foo", mod)
      method = Bindgen::Graph::Method.new(constructor_method, "", klass)

      method.diagnostics_path.should eq("Stuff::Foo#initialize()")
    end
  end
end
