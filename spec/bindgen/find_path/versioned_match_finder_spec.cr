require "../../spec_helper"

describe Bindgen::FindPath::VersionedMatchFinder do
  context "if prefer: Lowest" do
    it "yields a list going from lowest to highest" do
      list = [ "tool-2.0", "tool", "tool-1.0" ]
      config = Bindgen::FindPath::VersionCheck.from_yaml("prefer: Lowest")
      subject = Bindgen::FindPath::VersionedMatchFinder.new(list, config)

      collected = [ ] of String
      subject.each{|x| collected << x}

      collected.should eq([ "tool-1.0", "tool-2.0" ])
    end
  end

  context "if prefer: Highest" do
    it "yields a list going from highest to lowest" do
      list = [ "tool-2.0", "tool", "tool-1.0" ]
      config = Bindgen::FindPath::VersionCheck.from_yaml("prefer: Highest")
      subject = Bindgen::FindPath::VersionedMatchFinder.new(list, config)

      collected = [ ] of String
      subject.each{|x| collected << x}

      collected.should eq([ "tool-2.0", "tool-1.0" ])
    end
  end
end
