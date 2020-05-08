require "../../spec_helper"

private def run_check(yaml)
  config = Bindgen::FindPath::ShellCheck.from_yaml(yaml)
  checker = Bindgen::FindPath::ShellChecker.new(config)
  checker.check(__FILE__)
end

describe Bindgen::FindPath::ShellChecker do
  context "the command returns successfully" do
    it "returns true" do
      run_check("shell: 'test -f %'").should be_true
    end
  end

  context "the command fails" do
    it "returns false" do
      run_check("shell: 'test -d %'").should be_false
    end
  end

  context "the command doesn't exist" do
    it "returns false" do
      run_check("shell: './doesnt_event_exist % 2>&1'").should be_false
    end
  end
end
