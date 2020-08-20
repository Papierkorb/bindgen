require "../spec_helper"

describe "Template" do
  describe ".from_string" do
    it "constructs the no-op template from nil" do
      Bindgen::Template.from_string(nil).should be_a(Bindgen::Template::None)
    end

    it "can construct a simple template from a string" do
      Bindgen::Template.from_string("%x", simple: true).should eq(
        Bindgen::Template::Simple.new("%x"))
    end

    it "can construct a full template from a string" do
      expected = Bindgen::Template::Full.new("%x")
      Bindgen::Template.from_string("%x").should eq(expected)
      Bindgen::Template.from_string("%x", simple: false).should eq(expected)
    end
  end

  describe "#no_op?" do
    it "returns true for the no-op template" do
      Bindgen::Template::None.new.no_op?.should be_true
    end

    it "returns false for any other templates" do
      conversion1 = Bindgen::Template::Simple.new("%x")
      conversion2 = Bindgen::Template::Full.new("%x")
      conversion3 = Bindgen::Template::Seq.new(conversion1, conversion2)

      conversion1.no_op?.should be_false
      conversion2.no_op?.should be_false
      conversion3.no_op?.should be_false
    end
  end

  describe "#followed_by" do
    it "composes two templates" do
      conversion1 = Bindgen::Template::Simple.new("%x")
      conversion2 = Bindgen::Template::Full.new("%x")
      conversion3 = Bindgen::Template::Seq.new(conversion1, conversion2)

      conversion1.followed_by(conversion2).should eq(conversion3)
    end

    it "is #no_op? only when both templates are #no_op?" do
      op = Bindgen::Template::Simple.new("%x")
      no = Bindgen::Template::None.new

      op.followed_by(op).no_op?.should be_false
      op.followed_by(no).no_op?.should be_false
      no.followed_by(op).no_op?.should be_false
      no.followed_by(no).no_op?.should be_true
    end
  end

  describe "None#template" do
    it "returns the code unmodified" do
      Bindgen::Template::None.new.template("123").should eq("123")
    end
  end

  describe "Simple#template" do
    it "substitutes % with the supplied code" do
      Bindgen::Template::Simple.new("a%b%c").template("123").should eq("a123b123c")
    end

    it "substitutes %% with %" do
      Bindgen::Template::Simple.new("%%a%%%b%%%%c").template("123").should eq("%a%123b%%c")
    end
  end

  describe "Full#template" do
    it "follows Util.template rules for template substitution" do
      key, value = ENV.first
      Bindgen::Template::Full.new("%{#{key}}%").template("123").should eq("123#{value}123")
    end
  end

  describe "Seq#template" do
    it "composes two templates" do
      first = Bindgen::Template::Simple.new("%_a")
      second = Bindgen::Template::Simple.new("%_b")
      conversion = Bindgen::Template::Seq.new(first: first, second: second)
      conversion.template("c").should eq("c_a_b")
    end
  end
end
