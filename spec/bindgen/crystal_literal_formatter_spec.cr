require "../spec_helper"

describe Bindgen::CrystalLiteralFormatter do
  db = create_type_database
  subject = Bindgen::CrystalLiteralFormatter.new(db)

  describe "#literal" do
    it "supports String" do
      subject.literal("String", %<Hello"You>).should eq(%<"Hello\\"You">)
    end

    it "supports Bool" do
      subject.literal("Bool", true).should eq("true")
      subject.literal("Bool", false).should eq("false")
    end

    it "supports nil" do
      subject.literal("Object", true).should eq("nil")
    end

    it "supports Numbers" do
      subject.literal("Int32", 123).should eq("123")
    end

    it "returns nil if unknown type" do
      subject.literal("Array(String)", [ "hi" ]).should eq(nil)
    end

    it "returns nil if enum type" do
      subject.literal("CrWrappedEnum", 1).should eq(nil)
    end
  end

  describe "#number_literal" do
    it "supports UInt8" do
      subject.number_literal("UInt8", 5).should eq("5u8")
      subject.number_literal("UInt8", 7.2).should eq("7u8")
    end

    it "supports UInt16" do
      subject.number_literal("UInt16", 5).should eq("5u16")
      subject.number_literal("UInt16", 7.2).should eq("7u16")
    end

    it "supports UInt32" do
      subject.number_literal("UInt32", 5).should eq("5u32")
      subject.number_literal("UInt32", 7.2).should eq("7u32")
    end

    it "supports UInt64" do
      subject.number_literal("UInt64", 5).should eq("5u64")
      subject.number_literal("UInt64", 7.2).should eq("7u64")
    end

    it "supports Int8" do
      subject.number_literal("Int8", 5).should eq("5i8")
      subject.number_literal("Int8", 7.2).should eq("7i8")
    end

    it "supports Int16" do
      subject.number_literal("Int16", 5).should eq("5i16")
      subject.number_literal("Int16", 7.2).should eq("7i16")
    end

    it "supports Int32" do
      subject.number_literal("Int32", 5).should eq("5")
      subject.number_literal("Int32", 7.2).should eq("7")
    end

    it "supports Int64" do
      subject.number_literal("Int64", 5).should eq("5i64")
      subject.number_literal("Int64", 7.2).should eq("7i64")
    end

    it "supports Float32" do
      subject.number_literal("Float32", 5).should eq("5.0f32")
      subject.number_literal("Float32", 5.3).should eq("5.3f32")
    end

    it "supports Float64" do
      subject.number_literal("Float64", 5).should eq("5.0f64")
      subject.number_literal("Float64", 5.3).should eq("5.3f64")
    end

    it "returns nil if enum type" do
      subject.number_literal("CrWrappedEnum", 1).should eq(nil)
    end
  end

  describe "#qualified_enum_name" do
    context "normal enumeration" do
      type = Bindgen::Parser::Type.parse("CppWrappedEnum")

      it "supports known enum constant" do
        subject.qualified_enum_name(type, 1).should eq("CrWrappedEnum::One")
      end

      it "supports unknown enum constant" do
        subject.qualified_enum_name(type, 5).should eq("CrWrappedEnum.from_value(5)")
      end
    end

    context "flags enumeration" do
      type = Bindgen::Parser::Type.parse("CppWrappedFlags")

      it "supports unknown enum constant" do
        subject.qualified_enum_name(type, 9).should eq("CrWrappedFlags.from_value(9)")
      end

      it "supports single known enum constant" do
        subject.qualified_enum_name(type, 4).should eq("CrWrappedFlags.flags(Four)")
      end

      it "supports multiple known enum constants" do
        subject.qualified_enum_name(type, 3).should eq("CrWrappedFlags.flags(One, Two)")
      end

      it "supports implicit None constant" do
        subject.qualified_enum_name(type, 0).should eq("CrWrappedFlags::None")
      end
    end
  end
end
