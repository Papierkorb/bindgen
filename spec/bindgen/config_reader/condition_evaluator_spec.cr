require "../../spec_helper"

describe Bindgen::ConfigReader::ConditionEvaluator do
  variables = { "foo" => "bar", "under_scored" => "okay" }
  subject = Bindgen::ConfigReader::ConditionEvaluator.new(variables)

  awaiting_if = Bindgen::ConfigReader::ConditionState::AwaitingIf
  unmet = Bindgen::ConfigReader::ConditionState::Unmet
  met = Bindgen::ConfigReader::ConditionState::Met

  describe "is-checker" do
    it "foo is bar (= true)" do
      subject.evaluate("if_foo_is_bar", awaiting_if).should eq({ true, met })
    end

    it "foo is yadda (= false)" do
      subject.evaluate("if_foo_is_yadda", awaiting_if).should eq({ false, unmet })
    end

    it "doesnexist is there (= false)" do
      subject.evaluate("if_doesnexist_is_there", awaiting_if).should eq({ false, unmet })
    end

    it "doesnexist is '' (= true)" do
      subject.evaluate("if_doesnexist_is_", awaiting_if).should eq({ true, met })
    end
  end

  describe "isnt-checker" do
    it "foo isnt bar (= false)" do
      subject.evaluate("if_foo_isnt_bar", awaiting_if).should eq({ false, unmet })
    end

    it "foo isnt yadda (= true)" do
      subject.evaluate("if_foo_isnt_yadda", awaiting_if).should eq({ true, met })
    end

    it "doesnexist isnt there (= true)" do
      subject.evaluate("if_doesnexist_isnt_there", awaiting_if).should eq({ true, met })
    end

    it "doesnexist isnt '' (= false)" do
      subject.evaluate("if_doesnexist_isnt_", awaiting_if).should eq({ false, unmet })
    end
  end

  describe "matches-checker" do
    it "foo matches ^b.r (= true)" do
      subject.evaluate("if_foo_matches_^b.r", awaiting_if).should eq({ true, met })
    end

    it "foo matches ^ba[tz] (= false)" do
      subject.evaluate("if_foo_matches_^ba[tz]", awaiting_if).should eq({ false, unmet })
    end
  end

  describe "underscore separation" do
    it "works with if" do
      subject.evaluate("if_foo_is_bar", awaiting_if).should eq({ true, met })
      subject.evaluate("if_foo_is_yadda", awaiting_if).should eq({ false, unmet })
    end

    it "works with elsif" do
      subject.evaluate("elsif_foo_is_bar", unmet).should eq({ true, met })
      subject.evaluate("elsif_foo_is_yadda", unmet).should eq({ false, unmet })
    end

    it "works with variable using underscores" do
      subject.evaluate("if_under_scored_is_okay", awaiting_if).should eq({ true, met })
      subject.evaluate("if_under_scored_is_broken", awaiting_if).should eq({ false, unmet })
      subject.evaluate("if_under_scored_is_", awaiting_if).should eq({ false, unmet })
      subject.evaluate("if_under_scored_isnt_", awaiting_if).should eq({ true, met })
    end
  end

  describe "spaces" do
    it "works with if" do
      subject.evaluate("if foo is bar", awaiting_if).should eq({ true, met })
      subject.evaluate("if foo is yadda", awaiting_if).should eq({ false, unmet })
    end

    it "works with elsif" do
      subject.evaluate("elsif foo is bar", unmet).should eq({ true, met })
      subject.evaluate("elsif foo is yadda", unmet).should eq({ false, unmet })
    end

    it "works with variable using underscores" do
      subject.evaluate("if under_scored is okay", awaiting_if).should eq({ true, met })
      subject.evaluate("if under_scored is broken", awaiting_if).should eq({ false, unmet })
      subject.evaluate("if under_scored is ", awaiting_if).should eq({ false, unmet })
      subject.evaluate("if under_scored isnt ", awaiting_if).should eq({ true, met })
    end
  end

  describe "if-branch" do
    context "if state is AwaitingIf" do
      it "is true if the condition is true" do
        subject.evaluate("if_foo_is_bar", awaiting_if).should eq({ true, met })
      end

      it "is false if the condition is false" do
        subject.evaluate("if_foo_is_X", awaiting_if).should eq({ false, unmet })
      end
    end

    context "if state is Met" do
      it "is true if the condition is true" do
        subject.evaluate("if_foo_is_bar", met).should eq({ true, met })
      end

      it "is false if the condition is false" do
        subject.evaluate("if_foo_is_X", met).should eq({ false, unmet })
      end
    end

    context "if state is Unmet" do
      it "is true if the condition is true" do
        subject.evaluate("if_foo_is_bar", unmet).should eq({ true, met })
      end

      it "is false if the condition is false" do
        subject.evaluate("if_foo_is_X", unmet).should eq({ false, unmet })
      end
    end
  end

  describe "elsif-branch" do
    context "if state is AwaitingIf" do
      it "raises" do
        expect_raises(Bindgen::ConfigReader::ConditionEvaluator::Error) do
          subject.evaluate("elsif_foo_is_bar", awaiting_if)
        end
      end
    end

    context "if state is Met" do
      it "is false if the condition is true" do
        subject.evaluate("elsif_foo_is_bar", met).should eq({ false, met })
      end

      it "is false if the condition is false" do
        subject.evaluate("elsif_foo_is_X", met).should eq({ false, met })
      end
    end

    context "if state is Unmet" do
      it "is true if the condition is true" do
        subject.evaluate("elsif_foo_is_bar", unmet).should eq({ true, met })
      end

      it "is false if the condition is false" do
        subject.evaluate("elsif_foo_is_X", unmet).should eq({ false, unmet })
      end
    end
  end

  describe "else-branch" do
    context "if state is AwaitingIf" do
      it "raises" do
        expect_raises(Bindgen::ConfigReader::ConditionEvaluator::Error) do
          subject.evaluate("else", awaiting_if)
        end
      end
    end

    context "if state is Met" do
      it "returns false" do
        subject.evaluate("else", met).should eq({ false, met })
      end
    end

    context "if state is Unmet" do
      it "returns true" do
        subject.evaluate("else", unmet).should eq({ true, met })
      end
    end
  end

  context "on bad input" do
    it "raises" do
      expect_raises(Bindgen::ConfigReader::ConditionEvaluator::Error) do
        subject.evaluate("this isnt valid", awaiting_if)
      end
    end
  end
end
