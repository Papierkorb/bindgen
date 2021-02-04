require "../../spec_helper"

private def parse(*args)
  Bindgen::Parser::Type.parse(*args)
end

describe Bindgen::Parser::Type do
  describe "#decayed" do
    it "returns nil for base type" do # Rule 4
      parse("int").decayed.should be_nil
    end

    it "decays pointer depth" do # Rule 3
      parse("int **").decayed.should eq(parse("int *"))
      parse("int *").decayed.should eq(parse("int"))
    end

    it "decays reference" do # Rule 2
      parse("int *&").decayed.should eq(parse("int **"))
      parse("int &").decayed.should eq(parse("int *"))
    end

    it "decays const" do # Rule 1
      parse("const int *&").decayed.should eq(parse("int *&"))
      parse("const int &").decayed.should eq(parse("int &"))
      parse("const int *").decayed.should eq(parse("int *"))
      parse("const int").decayed.should eq(parse("int"))
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
      type.full_name.should eq("int *")
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
      type.full_name.should eq("int &")
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

    it "recognizes `Container<>`" do
      type = parse("Container<>")
      type.base_name.should eq("Container<>")
      type.full_name.should eq("Container<>")
      template = type.template
      template.should_not be_nil
      template.try(&.base_name).should eq("Container")
      template.try(&.full_name).should eq("Container<>")
      template.try(&.arguments.empty?).should be_true
    end

    it "recognizes `Container<int>`" do
      type = parse("Container<int>")
      type.base_name.should eq("Container<int>")
      type.full_name.should eq("Container<int>")
      template = type.template
      template.should_not be_nil
      template.try(&.base_name).should eq("Container")
      template.try(&.full_name).should eq("Container<int>")
      template.try(&.arguments.size).should eq(1)
      template.try(&.arguments[0]).should eq(parse("int"))
    end

    it "recognizes `Container<const int *>`" do
      type = parse("Container<const int *>")
      type.base_name.should eq("Container<const int *>")
      type.full_name.should eq("Container<const int *>")
      template = type.template
      template.should_not be_nil
      template.try(&.base_name).should eq("Container")
      template.try(&.full_name).should eq("Container<const int *>")
      template.try(&.arguments.size).should eq(1)
      template.try(&.arguments[0]).should eq(parse("const int *"))
    end

    it "recognizes `Container<int, bool>`" do
      type = parse("Container<int, bool>")
      type.base_name.should eq("Container<int, bool>")
      type.full_name.should eq("Container<int, bool>")
      template = type.template
      template.should_not be_nil
      template.try(&.base_name).should eq("Container")
      template.try(&.full_name).should eq("Container<int, bool>")
      template.try(&.arguments.size).should eq(2)
      template.try(&.arguments[0]).should eq(parse("int"))
      template.try(&.arguments[1]).should eq(parse("bool"))
    end

    it "recognizes `Container<Container<int> >`" do
      type = parse("Container<Container<int> >")
      type.base_name.should eq("Container<Container<int> >")
      type.full_name.should eq("Container<Container<int> >")
      template = type.template
      template.should_not be_nil
      template.try(&.base_name).should eq("Container")
      template.try(&.full_name).should eq("Container<Container<int> >")
      template.try(&.arguments.size).should eq(1)
      template.try(&.arguments[0]).should eq(parse("Container<int>"))
    end

    it "recognizes `Container<Container<int>>`" do
      type = parse("Container<Container<int>>")
      type.base_name.should eq("Container<Container<int>>")
      type.full_name.should eq("Container<Container<int>>")
      template = type.template
      template.should_not be_nil
      template.try(&.base_name).should eq("Container")
      template.try(&.full_name).should eq("Container<Container<int> >")
      template.try(&.arguments.size).should eq(1)
      template.try(&.arguments[0]).should eq(parse("Container<int>"))
    end

    it "recognizes `Container<const Container<int> &>`" do
      type = parse("Container<const Container<int> &>")
      type.base_name.should eq("Container<const Container<int> &>")
      type.full_name.should eq("Container<const Container<int> &>")
      template = type.template
      template.should_not be_nil
      template.try(&.base_name).should eq("Container")
      template.try(&.full_name).should eq("Container<const Container<int> &>")
      template.try(&.arguments.size).should eq(1)
      template.try(&.arguments[0]).should eq(parse("const Container<int> &"))
    end

    it "supports pointer depth offset" do
      parse("int", 1).pointer.should eq(1)
      parse("int *", 1).pointer.should eq(2)

      # don't add offset to template argument types
      type = parse("Container<int>", 1)
      type.pointer.should eq(1)
      type.template.not_nil!.arguments[0].pointer.should eq(0)
    end
  end

  describe "#substitute" do
    it "replaces `T` with another type" do
      parse("T").substitute("T", parse("int")).should eq(parse("int"))
      parse("U").substitute("T", parse("int")).should eq(parse("U"))
    end

    it "combines const-ness" do
      parse("const T").substitute("T", parse("int")).should eq(parse("const int"))
      parse("T").substitute("T", parse("const int")).should eq(parse("const int"))
      parse("const T").substitute("T", parse("const int")).should eq(parse("const int"))
    end

    it "combines references" do
      parse("T").substitute("T", parse("int &")).should eq(parse("int &"))
      parse("T &").substitute("T", parse("int")).should eq(parse("int &"))
      parse("T &").substitute("T", parse("int &")).should eq(parse("int &"))
    end

    it "combines pointers" do
      parse("T").substitute("T", parse("int *")).should eq(parse("int *"))
      parse("T *").substitute("T", parse("int")).should eq(parse("int *"))
      parse("T").substitute("T", parse("int **")).should eq(parse("int **"))
      parse("T *").substitute("T", parse("int *")).should eq(parse("int **"))
      parse("T **").substitute("T", parse("int")).should eq(parse("int **"))
    end

    it "combines mixtures of references and pointers" do
      parse("T &").substitute("T", parse("int *")).should eq(parse("int *&"))
      parse("T *").substitute("T", parse("int &")).should eq(parse("int *"))

      parse("T").substitute("T", parse("int *&")).should eq(parse("int *&"))
      parse("T *").substitute("T", parse("int *&")).should eq(parse("int **"))
      parse("T &").substitute("T", parse("int *&")).should eq(parse("int *&"))

      parse("T *&").substitute("T", parse("int")).should eq(parse("int *&"))
      parse("T *&").substitute("T", parse("int *")).should eq(parse("int **&"))
      parse("T *&").substitute("T", parse("int &")).should eq(parse("int *&"))
      parse("T *&").substitute("T", parse("int *&")).should eq(parse("int **&"))
    end

    it "replaces `T` in template arguments" do
      parse("Ref<T>").substitute("T", parse("int")).should eq(parse("Ref<int>"))
      parse("Ref<Ref<T>, T>").substitute("T", parse("int")).should eq(parse("Ref<Ref<int>, int>"))

      parse("Ref<T>").substitute("Ref", parse("int")).should eq(parse("Ref<T>"))
    end

    it "replaces `T` with another template type" do
      parse("T").substitute("T", parse("U<int>")).should eq(parse("U<int>"))
      parse("U<T, T>").substitute("T", parse("U<int>")).should eq(parse("U<U<int>, U<int> >"))
    end

    it "accepts multiple simultaneous replacements" do
      substs = {"T" => parse("int"), "U" => parse("char")}
      parse("T").substitute(substs).should eq(parse("int"))
      parse("U").substitute(substs).should eq(parse("char"))
      parse("T<T, U>").substitute(substs).should eq(parse("T<int, char>"))

      substs = {"X" => parse("Y"), "Y" => parse("X")}
      parse("T<X, Y>").substitute(substs).should eq(parse("T<Y, X>"))
    end
  end
end
