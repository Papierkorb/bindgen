require "../../spec_helper"

private def path(*parts)
  Bindgen::Graph::Path.from(*parts)
end

describe Bindgen::Graph::Path do
  describe "#[](Range)" do
    it "returns a sub-path" do
      path("a::b::c::d")[1..2].should eq(path("b::c"))
      path("a::b::c::d")[0..0].should eq(path("a"))
    end

    it "supports negative indices" do
      subject = path("a::b::c::d")
      subject[-3..2].should eq(path("b::c"))
      subject[1..-2].should eq(path("b::c"))
      subject[-3..-2].should eq(path("b::c"))
    end

    context "global path" do
      it "returns a global path only if the first part is included" do
        subject = path("::a::b::c::d")
        subject[0..2].should eq(path("::a::b::c"))
        subject[1..2].should eq(path("b::c"))
        subject[-3..-2].should eq(path("b::c"))
        subject[0..-4].should eq(path("::a"))
      end
    end

    context "self path" do
      it "returns a self path" do
        path("")[0..2].should eq(path(""))
      end
    end

    context "global root" do
      it "returns the global root" do
        path("::")[0..2].should eq(path("::"))
      end
    end
  end

  describe "#parent" do
    context "self path" do
      it "raises" do
        expect_raises(IndexError, /empty path/i) do
          path("").parent
        end
      end
    end

    context "global root" do
      it "raises" do
        expect_raises(IndexError, /empty path/i) do
          path("::").parent
        end
      end
    end

    context "single element local path" do
      it "returns a self path" do
        path("a").parent.should eq(path(""))
      end
    end

    context "single element global path" do
      it "returns the global root" do
        path("::a").parent.should eq(path("::"))
      end
    end

    it "returns the path of the parent" do
      path("a::b::c::d").parent.should eq(path("a::b::c"))
    end
  end

  describe "#last" do
    context "self path" do
      it "raises" do
        expect_raises(IndexError, /empty path/i) do
          path("").last
        end
      end
    end

    context "global root" do
      it "raises" do
        expect_raises(IndexError, /empty path/i) do
          path("::").last
        end
      end
    end

    context "single element path" do
      it "returns the same path" do
        path("a").last.should eq(path("a"))
      end
    end

    it "returns the last path part" do
      path("a::b::c::d").last.should eq(path("d"))
    end

    context "global path" do
      it "returns a local path" do
        path("::a::b").last.should eq(path("b"))
      end
    end
  end

  describe "#last_part" do
    context "self path" do
      it "raises" do
        expect_raises(IndexError, /empty path/i) do
          path("").last_part
        end
      end
    end

    context "global root" do
      it "raises" do
        expect_raises(IndexError, /empty path/i) do
          path("::").last_part
        end
      end
    end

    context "single element path" do
      it "returns that element" do
        path("a").last_part.should eq("a")
      end
    end

    it "returns the last path part" do
      path("a::b::c::d").last_part.should eq("d")
    end
  end

  describe "#join" do
    it "concatenates two paths" do
      path("a::b").join(path("c::d")).should eq(path("a::b::c::d"))
      path("::a::b").join(path("c::d")).should eq(path("::a::b::c::d"))

      path("a::b").join(path("")).should eq(path("a::b"))
      path("").join(path("a::b")).should eq(path("a::b"))
      path("").join(path("")).should eq(path(""))
    end

    context "joining to a global path" do
      it "returns a global path" do
        path("::a::b").join(path("c::d")).should eq(path("::a::b::c::d"))
        path("::a::b").join(path("")).should eq(path("::a::b"))
        path("::").join(path("c::d")).should eq(path("::c::d"))
      end
    end

    context "joining a global path to another path" do
      it "returns the global path" do
        path("a::b").join(path("::c::d")).should eq(path("::c::d"))
        path("").join(path("::c::d")).should eq(path("::c::d"))
        path("a::b").join(path("::")).should eq(path("::"))
      end
    end
  end

  describe "#self_path?" do
    context "on a self path" do
      it "returns true" do
        path("").self_path?.should be_true
      end
    end

    context "on a local path" do
      it "returns false" do
        path("a::b").self_path?.should be_false
      end
    end

    context "on a global path" do
      it "returns false" do
        path("::a::b").self_path?.should be_false
      end
    end
  end

  describe "#global?" do
    context "on a self path" do
      it "returns false" do
        path("").global?.should be_false
      end
    end

    context "on a local path" do
      it "returns false" do
        path("a::b").global?.should be_false
      end
    end

    context "on a global path" do
      it "returns true" do
        path("::a::b").global?.should be_true
      end
    end
  end

  describe "#local?" do
    context "on a self path" do
      it "returns true" do
        path("").local?.should be_true
      end
    end

    context "on a local path" do
      it "returns true" do
        path("a::b").local?.should be_true
      end
    end

    context "on a global path" do
      it "returns false" do
        path("::a::b").local?.should be_false
      end
    end
  end

  describe "#to_global" do
    root = Bindgen::Graph::Namespace.new("A")
    specific = root.platform_specific(Bindgen::Graph::Platform::Crystal)
    mod_b = Bindgen::Graph::Namespace.new("B", specific)
    mod_c = Bindgen::Graph::Namespace.new("C", mod_b)
    mod_d = Bindgen::Graph::Namespace.new("D", mod_c)

    context "given a global path" do
      it "returns self without checks" do
        subject = path("::Doesnt::Actually::Exist")
        subject.to_global(root).should eq(subject)
      end
    end

    context "given a self path" do
      it "returns a path pointing to '::'" do
        path("").to_global(root).should eq(path("::"))
      end
    end

    context "given a local path" do
      it "returns a global path" do
        path("C::D").to_global(mod_b).should eq(path("::A::B::C::D"))
      end

      it "raises if the local path doesn't exist" do
        expect_raises(Exception, /does not exist/i) do
          path("Unknown").to_global(mod_b)
        end
      end
    end
  end

  describe "#to_s" do
    context "given a self path" do
      it "returns empty string" do
        path("").to_s.should eq("")
      end
    end

    context "given a local path" do
      it "returns The::Path" do
        path("The::Path").to_s.should eq("The::Path")
      end
    end

    context "given a global path" do
      it "returns ::The::Path" do
        path("::The::Path").to_s.should eq("::The::Path")
      end
    end
  end

  describe "#inspect" do
    context "given a self path" do
      it "returns 'self'" do
        path("").inspect.should eq("self")
      end
    end

    context "given a local path" do
      it "returns The::Path" do
        path("The::Path").inspect.should eq("The::Path")
      end
    end

    context "given a global path" do
      it "returns ::The::Path" do
        path("::The::Path").inspect.should eq("::The::Path")
      end
    end
  end

  describe ".from(String)" do
    it "builds a local path" do
      subject = path("Foo::Bar")
      subject.parts.should eq(["Foo", "Bar"])
      subject.global?.should be_false
    end

    it "builds a global path" do
      subject = path("::Foo::Bar")
      subject.parts.should eq(["Foo", "Bar"])
      subject.global?.should be_true
    end

    it "builds the global path" do
      subject = path("::")
      subject.parts.empty?.should be_true
      subject.global?.should be_true
    end

    it "builds the self-path" do
      path("").self_path?.should be_true
    end

    it "ignores trailing namespace operators" do
      path("a::b::").should eq(path("a::b"))
    end

    it "ignores type arguments of generic types" do
      path("Foo(Stuff)::Bar").should eq(path("Foo::Bar"))
    end
  end

  describe ".from(Path)" do
    it "returns a copy of the path" do
      subject = path("a::b")
      copy = path(subject)
      copy.should eq(subject)
      copy.parts.should_not be(subject.parts)
    end
  end

  describe ".from(*)" do
    it "returns the concatenation of the given paths" do
      path("a", "b::c", path("d")).should eq(path("a::b::c::d"))
      path("::", "c", path(""), path("::"), "d").should eq(path("::d"))
    end
  end

  describe ".from(Enumerable)" do
    it "returns the concatenation of the given paths" do
      path({"Foo", "Bar::Baz"}).should eq(path("Foo::Bar::Baz"))
    end
  end

  # Path lookup tests

  # Builds this graph:  (With platform specifics)
  #        Root
  #       /    \
  #   Left     Right
  #  /    \   /     \
  # A     B  C      D
  root = Bindgen::Graph::Namespace.new("Root")
  specific_root = root.platform_specific(Bindgen::Graph::Platform::Crystal)
  left = Bindgen::Graph::Namespace.new("Left", specific_root)
  right = Bindgen::Graph::Namespace.new("Right", root)
  a = Bindgen::Graph::Namespace.new("A", left)
  b = Bindgen::Graph::Namespace.new("B", left)
  c = Bindgen::Graph::Namespace.new("C", right)
  specific_right = right.platform_specific(Bindgen::Graph::Platform::Cpp)
  d = Bindgen::Graph::Namespace.new("D", specific_right)

  describe ".local" do
    it "returns a self-path for going to the same node" do
      Bindgen::Graph::Path.local(a, a).self_path?.should be_true
    end

    it "finds the parent" do
      Bindgen::Graph::Path.local(a, left).should eq(path("Left"))
    end

    it "finds a direct child" do
      Bindgen::Graph::Path.local(left, a).should eq(path("A"))
    end

    it "finds an earlier parent" do
      Bindgen::Graph::Path.local(a, root).should eq(path("Root"))
    end

    it "finds a indirect child" do
      Bindgen::Graph::Path.local(root, a).should eq(path("Left::A"))
    end

    it "finds a direct sibling" do
      Bindgen::Graph::Path.local(left, right).should eq(path("Right"))
    end

    it "finds a siblings child" do
      Bindgen::Graph::Path.local(left, d).should eq(path("Right::D"))
    end

    it "finds a node in a different sub-graph" do
      Bindgen::Graph::Path.local(a, d).should eq(path("Right::D"))
    end

    it "builds a fake-global path if not found" do
      s = Bindgen::Graph::Namespace.new("S")
      t = Bindgen::Graph::Namespace.new("T", s)

      # a and t don't share any ancestor.
      Bindgen::Graph::Path.local(a, t).should eq(path("S::T"))
    end
  end

  describe ".global" do
    it "returns the global path to the node" do
      s = Bindgen::Graph::Namespace.new("S")
      t = Bindgen::Graph::Namespace.new("T", s)

      Bindgen::Graph::Path.global(t).should eq(path("::S::T"))
    end
  end

  describe "#lookup" do
    context "given a self path" do
      it "returns the base" do
        path("").lookup(a).should be(a)
      end
    end

    context "given a local path" do
      it "finds the parent" do
        path("Left").lookup(a).should be(left)
      end

      it "finds a direct child" do
        path("A").lookup(left).should be(a)
      end

      it "finds an earlier parent" do
        path("Root").lookup(a).should be(root)
      end

      it "finds a indirect child" do
        path("Left::A").lookup(root).should be(a)
      end

      it "finds a direct sibling" do
        path("Right").lookup(left).should be(right)
      end

      it "finds a siblings child" do
        path("Right::D").lookup(left).should be(d)
      end

      it "finds a siblings child from a parent" do
        path("Right::D").lookup(a).should be(d)
      end

      it "finds with a pseudo global" do
        path("Root::Right::D").lookup(left).should be(d)
      end

      it "returns nil if not found" do
        path("DoesntExist").lookup(root).should be_nil
      end

      # Builds this graph:
      #
      #   p1  -->  P
      #           / \
      # p2  -->  P   Q
      pending "doesn't find parents beyond the first matched parent" do
        p1 = Bindgen::Graph::Namespace.new("P")
        p2 = Bindgen::Graph::Namespace.new("P", p1)
        q = Bindgen::Graph::Namespace.new("Q", p1)

        path("P::Q").lookup(p2).should be_nil
      end
    end

    context "given a global path" do
      it "expects the first element to be the root element" do
        path("::Root").lookup(a).should be(root)
      end

      it "returns nil if first element is not the root" do
        path("::Whatever").lookup(a).should be_nil
        path("::Whatever::Root").lookup(a).should be_nil
        path("::Whatever::Root::Left").lookup(a).should be_nil
        path("::Whatever::Left").lookup(a).should be_nil
      end

      it "finds the root" do
        path("::").lookup(a).should be(root)
      end

      it "starts lookup from the root" do
        path("::Root::Right::D").lookup(a).should be(d)
        path("::Root::Root::Right::D").lookup(a).should_not be(d)
      end
    end
  end
end
