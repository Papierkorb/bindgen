require "../../spec_helper"

describe Bindgen::FindPath::GenericVersion do
  describe "<=>" do
    it "'' < '1'" do
      res = Bindgen::FindPath::GenericVersion.parse("") <=> Bindgen::FindPath::GenericVersion.parse("1")
      res.should eq -1
    end

    it "'0' > 'Z'" do
      res = Bindgen::FindPath::GenericVersion.parse("0") <=> Bindgen::FindPath::GenericVersion.parse("Z")
      res.should eq 1
    end

    it "'1.3' > '1.2'" do
      res = Bindgen::FindPath::GenericVersion.parse("1.3") <=> Bindgen::FindPath::GenericVersion.parse("1.2")
      res.should eq 1
    end

    it "'1.2' < '1.2.0'" do
      res = Bindgen::FindPath::GenericVersion.parse("1.2") <=> Bindgen::FindPath::GenericVersion.parse("1.2.0")
      res.should eq -1
    end

    it "'1.05' = '1.5'" do
      res = Bindgen::FindPath::GenericVersion.parse("1.05") <=> Bindgen::FindPath::GenericVersion.parse("1.5")
      res.should eq 0
    end
  end
end
