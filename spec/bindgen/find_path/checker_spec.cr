require "../../spec_helper"

describe Bindgen::FindPath::Checker do
  describe ".create" do
    context "if passed a PathCheck" do
      it "returns a PathChecker" do
        config = Bindgen::FindPath::PathCheck.new("foo", Bindgen::FindPath::Kind::File, nil, false)

        Bindgen::FindPath::Checker.create(config, false).should be_a(Bindgen::FindPath::PathChecker)
        Bindgen::FindPath::Checker.create(config, true).should be_a(Bindgen::FindPath::PathChecker)
      end
    end

    context "if passed a ShellCheck" do
      it "returns a ShellChecker" do
        config = Bindgen::FindPath::ShellCheck.new("/bin/false")

        Bindgen::FindPath::Checker.create(config, false).should be_a(Bindgen::FindPath::ShellChecker)
        Bindgen::FindPath::Checker.create(config, true).should be_a(Bindgen::FindPath::ShellChecker)
      end
    end
  end
end
