require "../../spec_helper"

class TestNode < Bindgen::Graph::Node
  def initialize(parent = nil)
    super("TestNode", parent)
  end

  def crystal_prefix
    "!"
  end
end

describe Bindgen::Graph::Node do
  describe "#initialize" do
    context "parent is a Container" do
      it "adds itself to the parent container" do
        parent = Bindgen::Graph::Namespace.new("Parent")
        node = TestNode.new(parent)

        node.parent.should be(parent)
        parent.nodes.should eq([node])
      end
    end

    context "parent is nil" do
      it "sets the parent to nil" do
        node = TestNode.new(parent: nil)
        node.parent.should be_nil
      end
    end
  end

  describe "#set_tag" do
    it "sets the key-value" do
      node = TestNode.new
      node.set_tag("foo", "bar")

      node.tags.should eq({"foo" => "bar"})
    end

    context "if the tag is already set" do
      it "raises" do
        node = TestNode.new
        node.set_tag("foo", "bar")

        expect_raises(KeyError, /already set/i) do
          node.set_tag("foo", "second fails")
        end
      end
    end
  end

  describe "#tag?" do
    it "returns the found tag" do
      node = TestNode.new
      node.set_tag("foo", "bar")

      node.tag?("foo").should eq("bar")
    end

    it "returns nil if not found" do
      node = TestNode.new
      node.tag?("foo").should be_nil
    end
  end

  describe "#tag" do
    it "returns the found tag" do
      node = TestNode.new
      node.set_tag("foo", "bar")

      node.tag("foo").should eq("bar")
    end

    it "raises if not found" do
      node = TestNode.new

      expect_raises(KeyError) do
        node.tag("foo")
      end
    end
  end

  describe "#full_path" do
    it "returns an array of nodes" do
      mod_a = Bindgen::Graph::Namespace.new("A")
      mod_b = Bindgen::Graph::Namespace.new("B", mod_a)
      node = TestNode.new(mod_b)

      node.full_path.should eq([mod_a, mod_b, node])
    end

    it "omits PlatformSpecifics" do
      mod_a = Bindgen::Graph::Namespace.new("A")
      # A single platform specific
      specific_a = mod_a.platform_specific(Bindgen::Graph::Platform::Cpp)
      mod_b = Bindgen::Graph::Namespace.new("B", specific_a)
      # A platform specific after another
      specific_b = mod_b.platform_specific(Bindgen::Graph::Platform::Cpp)
      specific_c = specific_b.platform_specific(Bindgen::Graph::Platform::Crystal)
      node = TestNode.new(mod_b)

      node.full_path.should eq([mod_a, mod_b, node])
    end
  end

  describe "#unspecific_parent" do
    context "the parent is a platform specific" do
      it "works with a single platform specific" do
        mod_a = Bindgen::Graph::Namespace.new("A")
        specific_a = mod_a.platform_specific(Bindgen::Graph::Platform::Cpp)
        node = TestNode.new(specific_a)

        node.unspecific_parent.should be(mod_a)
      end

      it "works with multiple platform specifics" do
        mod_a = Bindgen::Graph::Namespace.new("A")
        specific_a = mod_a.platform_specific(Bindgen::Graph::Platform::Cpp)
        specific_b = specific_a.platform_specific(Bindgen::Graph::Platform::Cpp)
        node = TestNode.new(specific_b)

        node.unspecific_parent.should be(mod_a)
      end
    end

    it "returns the parent" do
      mod_a = Bindgen::Graph::Namespace.new("A")
      node = TestNode.new(mod_a)
      node.unspecific_parent.should be(mod_a)
    end
  end

  describe "#path_name" do
    it "returns a readable name" do
      mod_a = Bindgen::Graph::Namespace.new("A")
      mod_b = Bindgen::Graph::Namespace.new("B", mod_a)
      node = TestNode.new(mod_b)

      node.path_name.should eq("A::B::TestNode")
    end

    it "skips platform specifics" do
      mod_a = Bindgen::Graph::Namespace.new("A")
      mod_b = Bindgen::Graph::Namespace.new("B", mod_a)
      specific_b = mod_b.platform_specific(Bindgen::Graph::Platform::Cpp)
      node = TestNode.new(specific_b)

      node.path_name.should eq("A::B::TestNode")
    end
  end

  describe "#diagnostics_path" do
    context "called on a platform specific" do
      it "includes the platform specific name" do
        mod_a = Bindgen::Graph::Namespace.new("A")
        mod_b = Bindgen::Graph::Namespace.new("B", mod_a)
        node = mod_b.platform_specific(Bindgen::Graph::Platform::Cpp)

        node.diagnostics_path.should eq("A::B::(Specific to Cpp)")
      end
    end

    it "omits platform specifics" do
      mod_a = Bindgen::Graph::Namespace.new("A")
      specific_a = mod_a.platform_specific(Bindgen::Graph::Platform::Cpp)
      node = Bindgen::Graph::Namespace.new("B", specific_a)

      node.diagnostics_path.should eq("A::B")
    end

    it "respects #crytal_prefix" do
      mod_a = Bindgen::Graph::Namespace.new("A")
      mod_b = Bindgen::Graph::Namespace.new("B", mod_a)
      node = TestNode.new(mod_b)

      node.diagnostics_path.should eq("A::B!TestNode")
    end
  end

  describe "#kind_name" do
    it "returns the readable kind of this node" do
      Bindgen::Graph::Namespace.new("A").kind_name.should eq("Namespace")
    end
  end

  describe "#find_root" do
    context "if the node is the root" do
      it "returns the node itself" do
        node = TestNode.new
        node.find_root.should be(node)
      end
    end

    it "finds the root" do
      mod_a = Bindgen::Graph::Namespace.new("A")
      specific_a = mod_a.platform_specific(Bindgen::Graph::Platform::Cpp)
      node = TestNode.new(specific_a)

      node.find_root.should be(mod_a)
    end
  end
end
