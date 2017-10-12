require "../../spec_helper"

describe Bindgen::Util::Tribool do
  unset_tribool = Bindgen::Util::Tribool.new(nil)
  true_tribool = Bindgen::Util::Tribool.new(true)
  false_tribool = Bindgen::Util::Tribool.new(false)

  describe ".unset" do
    it "returns a tribool in unset state" do
      Bindgen::Util::Tribool.unset.unset?.should be_true
    end
  end

  describe "#get" do
    context "if value is unset" do
      it "uses the default value" do
        unset_tribool.get(true).should eq(true)
        unset_tribool.get(false).should eq(false)
      end
    end

    context "if value is true" do
      it "returns true" do
        true_tribool.get(true).should eq(true)
        true_tribool.get(false).should eq(true)
      end
    end

    context "if value is false" do
      it "returns false" do
        false_tribool.get(true).should eq(false)
        false_tribool.get(false).should eq(false)
      end
    end
  end

  describe "#true?" do
    context "if value is unset" do
      it "uses the default value" do
        unset_tribool.true?(true).should eq(true)
        unset_tribool.true?(false).should eq(false)
      end
    end

    context "if value is true" do
      it "returns true" do
        true_tribool.true?(true).should eq(true)
        true_tribool.true?(false).should eq(true)
      end
    end

    context "if value is false" do
      it "returns false" do
        false_tribool.true?(true).should eq(false)
        false_tribool.true?(false).should eq(false)
      end
    end
  end

  describe "#false?" do
    context "if value is unset" do
      it "uses the default value" do
        unset_tribool.false?(true).should eq(false)
        unset_tribool.false?(false).should eq(true)
      end
    end

    context "if value is true" do
      it "returns false" do
        true_tribool.false?(true).should eq(false)
        true_tribool.false?(false).should eq(false)
      end
    end

    context "if value is false" do
      it "returns true" do
        false_tribool.false?(true).should eq(true)
        false_tribool.false?(false).should eq(true)
      end
    end
  end

  describe "#==" do
    it "can compare with a Bool" do
      (unset_tribool == true).should eq(false)
      (true_tribool == true).should eq(true)
      (false_tribool == true).should eq(false)

      (unset_tribool == false).should eq(false)
      (true_tribool == false).should eq(false)
      (false_tribool == false).should eq(true)
    end

    it "can compare with a Tribool" do
      (unset_tribool == unset_tribool).should eq(true)
      (true_tribool == unset_tribool).should eq(false)
      (false_tribool == unset_tribool).should eq(false)

      (unset_tribool == true_tribool).should eq(false)
      (true_tribool == true_tribool).should eq(true)
      (false_tribool == true_tribool).should eq(false)

      (unset_tribool == false_tribool).should eq(false)
      (true_tribool == false_tribool).should eq(false)
      (false_tribool == false_tribool).should eq(true)
    end
  end
end
