require "../../spec_helper"

private def common(list)
  Bindgen::Util::Prefix.common(list)
end

describe Bindgen::Util::Prefix do
  describe ".common" do
    context "on an empty list" do
      it "returns 0" do
        common([ ] of String).should eq(0)
      end
    end

    context "on a single string list" do
      it "returns 0" do
        common(%w[ Foo_BarBaz ]).should eq(0)
      end
    end

    context "on a multi element list" do
      it "returns the common prefix length" do
        common(%w[ NumOne NumTwo ]).should eq(3)
        common(%w[ FooA FooB ]).should eq(3)
      end
    end

    context "on a list with the prefix being a stand alone" do
      it "returns the common prefix length" do
        common(%w[ Foo FooBar ]).should eq(2)
      end
    end
  end
end
