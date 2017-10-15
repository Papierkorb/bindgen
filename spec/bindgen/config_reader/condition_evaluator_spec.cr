require "../../spec_helper"

describe Bindgen::ConfigReader::ConditionEvaluator do
  variables = { "foo" => "bar", "under_scored" => "okay" }
  subject = Bindgen::ConfigReader::ConditionEvaluator.new(variables)

  context "is-checker" do
    it "foo is bar (= true)" do
      subject.evaluate("if_foo_is_bar").should be_true
    end

    it "foo is yadda (= false)" do
      subject.evaluate("if_foo_is_yadda").should be_false
    end

    it "doesnexist is there (= false)" do
      subject.evaluate("if_doesnexist_is_there").should be_false
    end

    it "doesnexist is '' (= true)" do
      subject.evaluate("if_doesnexist_is_").should be_true
    end
  end

  context "isnt-checker" do
    it "foo isnt bar (= false)" do
      subject.evaluate("if_foo_isnt_bar").should be_false
    end

    it "foo isnt yadda (= true)" do
      subject.evaluate("if_foo_isnt_yadda").should be_true
    end

    it "doesnexist isnt there (= true)" do
      subject.evaluate("if_doesnexist_isnt_there").should be_true
    end

    it "doesnexist isnt '' (= false)" do
      subject.evaluate("if_doesnexist_isnt_").should be_false
    end
  end

  context "matches-checker" do
    it "foo matches ^b.r (= true)" do
      subject.evaluate("if_foo_matches_^b.r").should be_true
    end

    it "foo matches ^ba[tz] (= false)" do
      subject.evaluate("if_foo_matches_^ba[tz]").should be_false
    end
  end

  context "underscore separation" do
    it "works with if" do
      subject.evaluate("if_foo_is_bar").should be_true
      subject.evaluate("if_foo_is_yadda").should be_false
    end

    it "works with elsif" do
      subject.evaluate("elsif_foo_is_bar").should be_true
      subject.evaluate("elsif_foo_is_yadda").should be_false
    end

    it "works with variable using underscores" do
      subject.evaluate("if_under_scored_is_okay").should be_true
      subject.evaluate("if_under_scored_is_broken").should be_false
      subject.evaluate("if_under_scored_is_").should be_false
      subject.evaluate("if_under_scored_isnt_").should be_true
    end
  end

  context "spaces" do
    it "works with if" do
      subject.evaluate("if foo is bar").should be_true
      subject.evaluate("if foo is yadda").should be_false
    end

    it "works with elsif" do
      subject.evaluate("elsif foo is bar").should be_true
      subject.evaluate("elsif foo is yadda").should be_false
    end

    it "works with variable using underscores" do
      subject.evaluate("if under_scored is okay").should be_true
      subject.evaluate("if under_scored is broken").should be_false
      subject.evaluate("if under_scored is ").should be_false
      subject.evaluate("if under_scored isnt ").should be_true
    end
  end

  context "else" do
    it "is always true" do
      subject.evaluate("else").should be_true
    end
  end

  context "on bad input" do
    it "raises" do
      expect_raises(Bindgen::ConfigReader::ConditionEvaluator::Error) do
        subject.evaluate("this isnt valid")
      end
    end
  end
end
