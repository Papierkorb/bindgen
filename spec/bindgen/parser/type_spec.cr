require "../../spec_helper"

private def parse(*args)
  Bindgen::Parser::Type.parse(*args)
end

describe Bindgen::Parser::Type do
  describe "#decayed" do
    it "returns nil for base type" do # Rule 5
      parse("int").decayed.should be_nil
    end

    it "decays pointer depth" do # Rule 4
      parse("int **").decayed.should eq(parse("int *"))
      parse("int *").decayed.should eq(parse("int"))
    end

    it "decays reference" do # Rule 3
      parse("int *&").decayed.should eq(parse("int **"))
      parse("int &").decayed.should eq(parse("int *"))
    end

    it "decays const" do # Rule 2
      parse("const int *&").decayed.should eq(parse("int *&"))
      parse("const int &").decayed.should eq(parse("int &"))
      parse("const int *").decayed.should eq(parse("int *"))
      parse("const int").decayed.should eq(parse("int"))
    end

    it "decays arrays" do # Rule 1
      parse("int [4]").decayed.should eq(parse("int"))
      parse("int *[4]").decayed.should eq(parse("int *"))
      parse("int [4][3]").decayed.should eq(parse("int [3]"))
      parse("int *[4][3]").decayed.should eq(parse("int *[3]"))
    end
  end

  describe "#parse" do
    it "recognizes 'const int'" do
      type = parse("const int")
      type.const?.should be_true
      type.reference?.should be_false
      type.pointer.should eq(0)
      type.base_name.should eq("int")
      type.full_name.should eq("const int")
    end

    it "recognizes 'int *'" do
      type = parse("int *")
      type.const?.should be_false
      type.reference?.should be_false
      type.pointer.should eq(1)
      type.base_name.should eq("int")
      type.full_name.should eq("int *")
    end

    it "recognizes 'int*'" do
      type = parse("int*")
      type.const?.should be_false
      type.reference?.should be_false
      type.pointer.should eq(1)
      type.base_name.should eq("int")
      type.full_name.should eq("int*")
    end

    it "recognizes 'int &'" do
      type = parse("int &")
      type.const?.should be_false
      type.reference?.should be_true
      type.pointer.should eq(1)
      type.base_name.should eq("int")
      type.full_name.should eq("int &")
    end

    it "recognizes 'int&'" do
      type = parse("int&")
      type.const?.should be_false
      type.reference?.should be_true
      type.pointer.should eq(1)
      type.base_name.should eq("int")
      type.full_name.should eq("int&")
    end

    it "recognizes 'const int *'" do
      type = parse("const int *")
      type.const?.should be_true
      type.reference?.should be_false
      type.pointer.should eq(1)
      type.base_name.should eq("int")
      type.full_name.should eq("const int *")
    end

    it "recognizes 'const int **&'" do
      type = parse("const int **&")
      type.const?.should be_true
      type.reference?.should be_true
      type.pointer.should eq(3)
      type.base_name.should eq("int")
      type.full_name.should eq("const int **&")
    end

    it "recognizes 'const int **'" do
      type = parse("const int **")
      type.const?.should be_true
      type.reference?.should be_false
      type.pointer.should eq(2)
      type.base_name.should eq("int")
      type.full_name.should eq("const int **")
    end

    it "recognizes 'int [4]'" do
      type = parse("int [4]")
      type.const?.should be_false
      type.reference?.should be_false
      type.extents.should eq([4] of UInt64)
      type.pointer.should eq(1)
      type.base_name.should eq("int")
      type.full_name.should eq("int [4]")
    end

    it "recognizes 'int[4]'" do
      type = parse("int[4]")
      type.const?.should be_false
      type.reference?.should be_false
      type.extents.should eq([4] of UInt64)
      type.pointer.should eq(1)
      type.base_name.should eq("int")
      type.full_name.should eq("int[4]")
    end

    it "recognizes 'int []'" do
      type = parse("int []")
      type.const?.should be_false
      type.reference?.should be_false
      type.extents.should eq([0] of UInt64)
      type.pointer.should eq(1)
      type.base_name.should eq("int")
      type.full_name.should eq("int []")
    end

    it "recognizes 'int [4][3][2]'" do
      type = parse("int [4][3][2]")
      type.const?.should be_false
      type.reference?.should be_false
      type.extents.should eq([4, 3, 2] of UInt64)
      type.pointer.should eq(3)
      type.base_name.should eq("int")
      type.full_name.should eq("int [4][3][2]")
    end

    it "recognizes 'int [][3][2]'" do
      type = parse("int [][3][2]")
      type.const?.should be_false
      type.reference?.should be_false
      type.extents.should eq([0, 3, 2] of UInt64)
      type.pointer.should eq(3)
      type.base_name.should eq("int")
      type.full_name.should eq("int [][3][2]")
    end

    it "recognizes 'const int [4]'" do
      type = parse("const int [4]")
      type.const?.should be_true
      type.reference?.should be_false
      type.extents.should eq([4] of UInt64)
      type.pointer.should eq(1)
      type.base_name.should eq("int")
      type.full_name.should eq("const int [4]")
    end

    it "recognizes 'int * [4]'" do
      type = parse("int * [4]")
      type.const?.should be_false
      type.reference?.should be_false
      type.extents.should eq([4] of UInt64)
      type.pointer.should eq(2)
      type.base_name.should eq("int")
      type.full_name.should eq("int * [4]")
    end

    pending "recognizes 'int (&) [4]'" do
    end

    pending "recognizes 'int [4] *'" do
    end

    it "supports pointer depth offset" do
      parse("int", 1).pointer.should eq(1)
      parse("int *", 1).pointer.should eq(2)
    end
  end
end
