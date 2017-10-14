require  "../../spec_helper"

describe Bindgen::FindPath::Kind do
  describe "Directory#exists?" do
    context "on a file" do
      it "returns false" do
        Bindgen::FindPath::Kind::Directory.exists?(__FILE__).should be_false
      end
    end

    context "on a directory" do
      it "returns true" do
        Bindgen::FindPath::Kind::Directory.exists?(__DIR__).should be_true
      end
    end

    context "on a path that doesn't exist" do
      it "returns false" do
        Bindgen::FindPath::Kind::Directory.exists?("doesnt_exist").should be_false
      end
    end
  end

  describe "File#exists?" do
    context "on a file" do
      it "returns true" do
        Bindgen::FindPath::Kind::File.exists?(__FILE__).should be_true
      end
    end

    context "on a directory" do
      it "returns false" do
        Bindgen::FindPath::Kind::File.exists?(__DIR__).should be_false
      end
    end

    context "on a path that doesn't exist" do
      it "returns false" do
        Bindgen::FindPath::Kind::File.exists?("doesnt_exist").should be_false
      end
    end
  end
end
