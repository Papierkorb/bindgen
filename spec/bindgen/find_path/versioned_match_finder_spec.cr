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

  describe "version capturing" do
    it "should store the selected version in the additional variable" do
      list = [ "tool-2.0", "tool", "tool-1.0" ]
      config = Bindgen::FindPath::VersionCheck.from_yaml("variable: FOO_VER")
      subject = Bindgen::FindPath::VersionedMatchFinder.new(list, config)

      subject.each{ }

      subject.additional_variables.should eq({ "FOO_VER" => "2.0" })
    end

    context "if no candidate was found" do
      it "doesn't set the variable" do
        list = [ "tool" ]
        config = Bindgen::FindPath::VersionCheck.from_yaml("variable: FOO_VER")
        subject = Bindgen::FindPath::VersionedMatchFinder.new(list, config)

        subject.each{ }

        subject.additional_variables.should be_nil
      end
    end
  end
end
