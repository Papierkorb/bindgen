require "../../spec_helper"

private def path(parts)
  Bindgen::Graph::Path.from(parts)
end

describe Bindgen::Graph::Path do
  describe "#[](Range)" do
    context "self path" do
      it "returns path with nil-nodes" do
        path(nil)[0..2].nodes.should be_nil
      end
    end

    it "returns a sub-path" do
      path(%w[ a b c d ])[1..2].nodes.should eq(%w[ b c ])
    end
  end

  describe "#parent" do
    context "self path" do
      it "returns a self path" do
        path(nil).parent.nodes.should be_nil
      end
    end

    context "single element path" do
      it "returns the global path" do
        path(%w[ a ]).parent.nodes.try(&.empty?).should be_true
      end
    end

    it "returns the path of the parent" do
      path(%w[ a b c d ]).parent.nodes.should eq(%w[ a b c ])
    end
  end

  describe "#last" do
    context "self path" do
      it "returns a self path" do
        path(nil).last.nodes.should be_nil
      end
    end

    context "single element path" do
      it "returns the same path" do
        path(%w[ a ]).last.nodes.should eq(%w[ a ])
      end
    end

    it "returns the last path part" do
      path(%w[ a b c d ]).last.nodes.should eq(%w[ d ])
    end
  end

  describe "#last_part" do
    context "self path" do
      it "raises" do
        expect_raises(IndexError, /self-path/i) do
          path(nil).last_part
        end
      end
    end

    context "single element path" do
      it "returns that element" do
        path(%w[ a ]).last_part.should eq("a")
      end
    end

    it "returns the last path part" do
      path(%w[ a b c d ]).last_part.should eq("d")
    end
  end

  describe "#self?" do
    context "on a self path" do
      it "returns true" do
        path(nil).self?.should be_true
      end
    end

    context "on a local path" do
      it "returns false" do
        path(%w[ a b ]).self?.should be_false
      end
    end

    context "on a global path" do
      it "returns false" do
        path([ "", "a", "b" ]).self?.should be_false
      end
    end
  end

  describe "#global?" do
    context "on a self path" do
      it "returns false" do
        path(nil).global?.should be_false
      end
    end

    context "on a local path" do
      it "returns false" do
        path(%w[ a b ]).global?.should be_false
      end
    end

    context "on a global path" do
      it "returns true" do
        path([ "", "a", "b" ]).global?.should be_true
      end
    end
  end

  describe "#local?" do
    context "on a self path" do
      it "returns true" do
        path(nil).local?.should be_true
      end
    end

    context "on a local path" do
      it "returns true" do
        path(%w[ a b ]).local?.should be_true
      end
    end

    context "on a global path" do
      it "returns false" do
        path([ "", "a", "b" ]).local?.should be_false
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
        subject = path([ "", "Doesnt", "Actually", "Exist" ])
        subject.to_global(root).should eq(subject)
      end
    end

    context "given a self path" do
      it "returns a path pointing to '::'" do
        path(nil).to_global(root).should eq(path(%w[]))
      end
    end

    context "given a local path" do
      it "returns a global path" do
        path(%w[ C D ]).to_global(mod_b).should eq(path([ "", "A", "B", "C", "D" ]))
      end

      it "raises if the local path doesn't exist" do
        expect_raises(Exception, /does not exist/i) do
          path(%w[ Unknown ]).to_global(mod_b)
        end
      end
    end
  end

  describe "#to_s" do
    context "given a self path" do
      it "returns empty string" do
        path(nil).to_s.should eq("")
      end
    end

    context "given a local path" do
      it "returns The::Path" do
        path(%w[ The Path ]).to_s.should eq("The::Path")
      end
    end

    context "given a global path" do
      it "returns ::The::Path" do
        path([ "", "The", "Path" ]).to_s.should eq("::The::Path")
      end
    end
  end

  describe "#inspect" do
    context "given a self path" do
      it "returns 'self'" do
        path(nil).inspect.should eq("self")
      end
    end

    context "given a local path" do
      it "returns The::Path" do
        path(%w[ The Path ]).inspect.should eq("The::Path")
      end
    end

    context "given a global path" do
      it "returns ::The::Path" do
        path([ "", "The", "Path" ]).inspect.should eq("::The::Path")
      end
    end
  end

  describe ".from(String)" do
    it "works with normal paths" do
      path("Foo::Bar").nodes.should eq(%w[ Foo Bar ])
    end

    it "works with generics paths" do
      path("Foo(Stuff)::Bar").nodes.should eq(%w[ Foo Bar ])
    end

    it "builds a global path" do
      path("::Foo::Bar").nodes.should eq([ "", "Foo", "Bar" ])
    end

    it "builds the global path" do
      path("::").nodes.should eq([ "" ])
    end
  end

  describe ".from(Enumerable)" do
    it "uses the list" do
      path({ "Foo", "Bar" }).nodes.should eq(%w[ Foo Bar ])
    end
  end

  describe ".from(Nil)" do
    it "returns a self path" do
      path(nil).nodes.should be_nil
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
      Bindgen::Graph::Path.local(a, a).self?.should be_true
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

      Bindgen::Graph::Path.global(t).nodes.should eq([ "", "S", "T" ])
    end
  end

  describe "#lookup" do
    context "given a self path" do
      it "returns the base" do
        path(nil).lookup(a).should be(a)
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

      it "finds with a pseudo global" do
        path("Root::Right::D").lookup(left).should be(d)
      end

      it "returns nil if not found" do
        path("DoesntExist").lookup(root).should be_nil
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
      end
    end
  end
end
