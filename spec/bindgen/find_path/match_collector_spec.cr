require "../../spec_helper"

describe Bindgen::FindPath::MatchCollector do
  subject = Bindgen::FindPath::MatchCollector.new

  context "if nothing found" do
    it "returns nil" do
      subject.collect([] of String).should be_nil
    end
  end

  context "if one match found" do
    it "returns the match" do
      subject.collect(["foo"]).should eq("foo")
    end
  end

  context "if many matches found" do
    it "returns the first match" do
      subject.collect(["foo", "bar"]).should eq("foo")
    end
  end
end
