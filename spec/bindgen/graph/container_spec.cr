require "../../spec_helper"

class TestContainer < Bindgen::Graph::Container
  getter! foo_module : Bindgen::Graph::Namespace?
  getter! bar_module : Bindgen::Graph::Namespace?
  getter! cpp_specific : Bindgen::Graph::PlatformSpecific?
  getter! cpp_crystal_specific : Bindgen::Graph::PlatformSpecific?

  def initialize
    super("TestRoot")

    @foo_module = Bindgen::Graph::Namespace.new("FooModule", self)
    @bar_module = Bindgen::Graph::Namespace.new("BarModule", self)

    @cpp_specific = Bindgen::Graph::PlatformSpecific.new(Bindgen::Graph::Platform::Cpp, self)
    @cpp_crystal_specific = Bindgen::Graph::PlatformSpecific.new(Bindgen::Graph::Platforms.flags(Cpp, Crystal), self)
  end
end

describe Bindgen::Graph::Container do
  describe "#by_name" do
    it "returns the found node" do
      subject = TestContainer.new

      subject.by_name("FooModule").should be(subject.foo_module)
      subject.by_name("BarModule").should be(subject.bar_module)
    end

    it "raises if not found" do
      subject = TestContainer.new

      expect_raises(Exception, /did not find node/i) do
        subject.by_name("Unknown")
      end
    end
  end

  describe "#by_name?" do
    it "returns the found node" do
      subject = TestContainer.new

      subject.by_name?("FooModule").should be(subject.foo_module)
      subject.by_name?("BarModule").should be(subject.bar_module)
    end

    it "returns nil if not found" do
      subject = TestContainer.new
      subject.by_name?("Unknown").should be_nil
    end
  end

  describe "#platform_specific" do
    context "on Platform" do
      it "returns the found PlatformSpecific" do
        subject = TestContainer.new
        platform = Bindgen::Graph::Platform::Cpp

        subject.platform_specific(platform).should be(subject.cpp_specific)
      end

      it "creates a new node if not found" do
        subject = TestContainer.new
        platform = Bindgen::Graph::Platform::Crystal

        specific = subject.platform_specific(platform)
        specific.parent.should be(subject)
        specific.should_not be(subject.cpp_specific)
        specific.should_not be(subject.cpp_crystal_specific)
        specific.platforms.should eq(platform.as_flag)
      end
    end

    context "on Platforms" do
      it "returns the found PlatformSpecific" do
        subject = TestContainer.new
        platform = Bindgen::Graph::Platforms.flags(Cpp, Crystal)

        subject.platform_specific(platform).should be(subject.cpp_crystal_specific)
      end

      it "creates a new node if not found" do
        subject = TestContainer.new
        platform = Bindgen::Graph::Platforms.flags(Crystal, CrystalBinding)

        specific = subject.platform_specific(platform)
        specific.parent.should be(subject)
        specific.should_not be(subject.cpp_specific)
        specific.should_not be(subject.cpp_crystal_specific)
        specific.platforms.should eq(platform)
      end
    end
  end

  describe "#platform_specific?" do
    context "on Platform" do
      it "returns the found PlatformSpecific" do
        subject = TestContainer.new
        platform = Bindgen::Graph::Platform::Cpp

        subject.platform_specific?(platform).should be(subject.cpp_specific)
      end

      it "returns nil if not found" do
        subject = TestContainer.new
        platform = Bindgen::Graph::Platform::Crystal

        subject.platform_specific?(platform).should be_nil
      end
    end

    context "on Platforms" do
      it "returns the found PlatformSpecific" do
        subject = TestContainer.new
        platform = Bindgen::Graph::Platforms.flags(Cpp, Crystal)

        subject.platform_specific?(platform).should be(subject.cpp_crystal_specific)
      end

      it "returns nil if not found" do
        subject = TestContainer.new
        platform = Bindgen::Graph::Platforms.flags(Crystal, CrystalBinding, Cpp)

        subject.platform_specific?(platform).should be_nil
      end
    end
  end
end
