require "../spec_helper"

private def parse(*args)
  Bindgen::Parser::Type.parse(*args)
end

private def new_database
  Bindgen::TypeDatabase.new(Bindgen::TypeDatabase::Configuration.new, "boehmgc-cpp", with_builtins: false)
end

describe Bindgen::TypeDatabase do
  db = new_database
  db.add("CppType", cpp_type: "TheCppType", generate_wrapper: false)
  db.add("foo", crystal_type: "value")
  db.add("foo *", crystal_type: "pointer")
  db.add("bar", crystal_type: "bar-value")

  describe "type lookup" do
    context "type decay matching" do
      it "decays 'bar *' to 'bar'" do
        db[parse("bar *")].crystal_type.should eq("bar-value")
      end

      it "decays 'bar &' to 'bar'" do
        db[parse("bar *")].crystal_type.should eq("bar-value")
      end

      it "matches 'foo *' to 'foo *'" do
        db[parse("foo *")].crystal_type.should eq("pointer")
      end

      it "matches 'foo' to 'foo'" do
        db[parse("foo")].crystal_type.should eq("value")
      end
    end

    context "aliasing" do
      db.add_alias("Aliaser", alias_for: "Aliasee")
      db.add("Aliasee", crystal_type: "aliased-thing")

      it "detects recursive aliases" do
        expect_raises(Exception, /recursive type alias/i) do
          db.add_alias("Recursive", alias_for: "Recursive")
        end
        expect_raises(Exception, /recursive type alias/i) do
          db.add_alias("T", alias_for: "T *")
        end
        expect_raises(Exception, /recursive type alias/i) do
          db.add_alias("T", alias_for: "Temp<T>")
        end

        expect_raises(Exception, /recursive type alias/i) do
          db2 = new_database
          db2.add_alias("T", alias_for: "U")
          db2.add_alias("U", alias_for: "T")
        end
        expect_raises(Exception, /recursive type alias/i) do
          db2 = new_database
          db2.add_alias("T", alias_for: "U *")
          db2.add_alias("U", alias_for: "T *")
        end
      end

      it "finds aliased type-name" do
        db["Aliaser"].crystal_type.should eq("aliased-thing")
      end

      it "finds aliased type" do
        db[parse("Aliaser")].crystal_type.should eq("aliased-thing")
      end

      it "finds recursive aliased type" do
        db.add_alias("Aliaserer", alias_for: "Aliaser")
        db[parse("Aliaserer")].crystal_type.should eq("aliased-thing")

        db.add("temp<Aliasee>", crystal_type: "temp-aliasee")
        db[parse("temp<Aliaserer>")].crystal_type.should eq("temp-aliasee")
      end
    end
  end

  describe "#[]" do
    it "raises if type name not found" do
      expect_raises(KeyError) do
        db["DoesntExist"]
      end
    end

    it "raises if type not found" do
      expect_raises(KeyError) do
        db[parse("DoesntExist *")]
      end
    end
  end

  describe "#try_or" do
    context "the rule doesn't exist" do
      it "returns the default" do
        db.try_or("DoesntExist", "default", &.cpp_type).should eq("default")
      end

      it "supports false as default value" do
        db.try_or("", false, &.generate_wrapper?).should be_false
      end
    end

    context "the field is nil" do
      it "returns the default" do
        db.try_or("foo", "default", &.cpp_type).should eq("default")
      end
    end

    context "the rules exist and the field is set" do
      it "returns the field" do
        db.try_or("CppType", "default", &.cpp_type).should eq("TheCppType")
      end

      it "supports false as field value" do
        db.try_or("CppType", true, &.generate_wrapper?).should be_false
      end
    end
  end

  describe "#get_or_add" do
    it "returns the rules" do
      db.get_or_add("CppType").cpp_type.should eq("TheCppType")
    end

    it "creates and returns new rules" do
      db2 = new_database
      db["NewRules"]?.should be_nil
      new_rules = db.get_or_add("NewRules")
      db["NewRules"]?.should be(new_rules)
    end
  end
end
