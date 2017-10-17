require "../../spec_helper"

describe Bindgen::FindPath::ListMatchCollector do
  config = Bindgen::FindPath::ListConfig.new(
    separator: "|",
    template: ">%<",
  )

  subject = Bindgen::FindPath::ListMatchCollector.new(config)

  context "if nothing found" do
    it "returns nil" do
      subject.collect([ ] of String).should be_nil
    end
  end

  context "if one match found" do
    it "returns the templated match" do
      subject.collect([ "foo" ]).should eq(">foo<")
    end
  end

  context "if many matches found" do
    it "returns the templated and joined matches" do
      subject.collect([ "foo", "bar" ]).should eq(">foo<|>bar<")
    end
  end
end
