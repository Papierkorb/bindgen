require "../../spec_helper"

private class CallAnalyzer
  include Bindgen::CallAnalyzer::CppMethods

  def initialize(@db : Bindgen::TypeDatabase)
  end
end

describe Bindgen::CallAnalyzer::CppMethods do
  subject = CallAnalyzer.new(create_type_database)

  describe "#pass_to_cpp" do
    context "by-value and type is copied" do
      it "passes by-value" do
        result = subject.pass_to_cpp(Parser.type("Copied"))

        result.type.should eq(Parser.type("Copied"))
        result.type_name.should eq("Copied")
        result.reference.should eq(false)
        result.pointer.should eq(0)
        result.conversion.should eq(nil)
      end
    end

    context "by-value and type is NOT copied" do
      it "passes by-reference" do
        result = subject.pass_to_cpp(Parser.type("Foo"))

        result.type.should eq(Parser.type("Foo"))
        result.type_name.should eq("Foo")
        result.reference.should eq(true)
        result.pointer.should eq(0)
        result.conversion.should eq(nil)
      end
    end

    context "by-reference" do
      it "passes by-reference" do
        result = subject.pass_to_cpp(Parser.type("Foo &"))

        result.type.should eq(Parser.type("Foo &"))
        result.type_name.should eq("Foo")
        result.reference.should eq(true)
        result.pointer.should eq(0)
        result.conversion.should eq(nil)
      end
    end

    context "by-pointer" do
      it "passes by-pointer" do
        result = subject.pass_to_cpp(Parser.type("Foo *"))

        result.type.should eq(Parser.type("Foo *"))
        result.type_name.should eq("Foo")
        result.reference.should eq(false)
        result.pointer.should eq(1)
        result.conversion.should eq(nil)
      end
    end

    context "with user configuration" do
      it "supports rules.to_cpp" do
        result = subject.pass_to_cpp(Parser.type("HasToFromCpp &"))

        result.type.should eq(Parser.type("HasToFromCpp &"))
        result.type_name.should eq("HasToFromCpp")
        result.reference.should eq(true)
        result.pointer.should eq(0)
        result.conversion.should eq("my_to_cpp(%)")
      end

      it "supports rules.cpp_type" do
        result = subject.pass_to_cpp(Parser.type("HasCppType &"))

        result.type.should eq(Parser.type("HasCppType &"))
        result.type_name.should eq("MyType")
        result.reference.should eq(true)
        result.pointer.should eq(0)
        result.conversion.should eq(nil)
      end

      it "supports rules.pass_by" do
        result = subject.pass_to_cpp(Parser.type("ForceByReference"))

        result.type.should eq(Parser.type("ForceByReference"))
        result.type_name.should eq("ForceByReference")
        result.reference.should eq(true)
        result.pointer.should eq(0)
        result.conversion.should eq(nil)
      end
    end
  end

  describe "#pass_to_crystal" do
    context "is_constructor: true" do
      context "type is copied" do
        it "passes by-value" do
          result = subject.pass_to_crystal(Parser.type("Copied *"), is_constructor: true)

          result.type.should eq(Parser.type("Copied *"))
          result.type_name.should eq("Copied")
          result.reference.should eq(false)
          result.pointer.should eq(0)
          result.conversion.should eq(nil)
        end
      end

      context "type is NOT copied" do
        it "passes by-pointer" do
          result = subject.pass_to_crystal(Parser.type("Foo *"), is_constructor: true)

          result.type.should eq(Parser.type("Foo *"))
          result.type_name.should eq("Foo")
          result.reference.should eq(false)
          result.pointer.should eq(1)
          result.conversion.should eq(nil)
        end
      end
    end

    context "is_constructor: false" do
      context "by-reference" do
        it "copies and passes by-pointer" do
          result = subject.pass_to_crystal(Parser.type("Foo&"), is_constructor: false)

          result.type.should eq(Parser.type("Foo&"))
          result.type_name.should eq("Foo")
          result.reference.should eq(false)
          result.pointer.should eq(1)
          result.conversion.should eq("new (UseGC) Foo (%)")
        end
      end

      context "by-pointer" do
        it "passes by-pointer" do
          result = subject.pass_to_crystal(Parser.type("Foo*"), is_constructor: false)

          result.type.should eq(Parser.type("Foo*"))
          result.type_name.should eq("Foo")
          result.reference.should eq(false)
          result.pointer.should eq(1)
          result.conversion.should eq(nil)
        end
      end

      context "by-value" do
        context "type is copied" do
          it "passes by-value" do
            result = subject.pass_to_crystal(Parser.type("Copied"), is_constructor: false)

            result.type.should eq(Parser.type("Copied"))
            result.type_name.should eq("Copied")
            result.reference.should eq(false)
            result.pointer.should eq(0)
            result.conversion.should eq(nil)
          end
        end

        context "type is NOT copied" do
          it "passes by-pointer" do
            result = subject.pass_to_crystal(Parser.type("Foo"), is_constructor: false)

            result.type.should eq(Parser.type("Foo"))
            result.type_name.should eq("Foo")
            result.reference.should eq(false)
            result.pointer.should eq(1)
            result.conversion.should eq("new (UseGC) Foo (%)")
          end
        end
      end
    end

    context "with user configuration" do
      it "supports rules.from_cpp" do
        result = subject.pass_to_crystal(Parser.type("HasToFromCpp &"))

        result.type.should eq(Parser.type("HasToFromCpp &"))
        result.type_name.should eq("HasToFromCpp")
        result.reference.should eq(false)
        result.pointer.should eq(1)
        result.conversion.should eq("my_from_cpp(%)")
      end

      it "supports rules.cpp_type" do
        result = subject.pass_to_crystal(Parser.type("HasCppType &"))

        result.type.should eq(Parser.type("HasCppType &"))
        result.type_name.should eq("MyType")
        result.reference.should eq(false)
        result.pointer.should eq(1)
        result.conversion.should eq("new (UseGC) MyType (%)")
      end

      it "supports rules.pass_by" do
        result = subject.pass_to_crystal(Parser.type("ForceByReference"))

        result.type.should eq(Parser.type("ForceByReference"))
        result.type_name.should eq("ForceByReference")
        result.reference.should eq(true)
        result.pointer.should eq(0)
        result.conversion.should eq(nil)
      end
    end
  end

  describe "#passthrough_to_crystal" do
    context "by-value" do
      context "type is copied" do
        it "passes by-value" do
          result = subject.passthrough_to_crystal(Parser.type("Copied"))

          result.type.should eq(Parser.type("Copied"))
          result.type_name.should eq("Copied")
          result.reference.should eq(false)
          result.pointer.should eq(0)
          result.conversion.should eq(nil)
        end
      end

      context "type is NOT copied" do
        it "copies and passes by-pointer" do
          result = subject.passthrough_to_crystal(Parser.type("Foo"))

          result.type.should eq(Parser.type("Foo"))
          result.type_name.should eq("Foo")
          result.reference.should eq(false) # Doesn't change external type!
          result.pointer.should eq(0)
          result.conversion.should eq("new (UseGC) Foo (%)")
        end
      end
    end

    context "by-reference" do
      it "copies and passes by-pointer" do
        result = subject.passthrough_to_crystal(Parser.type("Foo&"))

        result.type.should eq(Parser.type("Foo&"))
        result.type_name.should eq("Foo")
        result.reference.should eq(true) # Doesn't change external type!
        result.pointer.should eq(0)
        result.conversion.should eq("new (UseGC) Foo (%)")
      end
    end

    context "by-pointer" do
      it "passes by-pointer" do
        result = subject.passthrough_to_crystal(Parser.type("Foo*"))

        result.type.should eq(Parser.type("Foo*"))
        result.type_name.should eq("Foo")
        result.reference.should eq(false)
        result.pointer.should eq(1)
        result.conversion.should eq(nil)
      end
    end

    context "with user configuration" do
      it "supports rules.from_cpp" do
        result = subject.passthrough_to_crystal(Parser.type("HasToFromCpp &"))

        result.type.should eq(Parser.type("HasToFromCpp &"))
        result.type_name.should eq("HasToFromCpp")
        result.reference.should eq(true)
        result.pointer.should eq(0)
        result.conversion.should eq("my_from_cpp(%)")
      end

      it "supports rules.cpp_type" do
        result = subject.passthrough_to_crystal(Parser.type("HasCppType &"))

        # Signals the original C++ to the outside, but uses the rules internally.
        result.type.should eq(Parser.type("HasCppType &"))

        # Use C++ rule to the outside vvv
        result.type_name.should eq("HasCppType")
        result.reference.should eq(true)
        result.pointer.should eq(0)
        # Use Crystal rule for conversion vvv
        result.conversion.should eq("new (UseGC) MyType (%)")
      end

      it "supports rules.pass_by" do
        result = subject.passthrough_to_crystal(Parser.type("ForceByReference"))

        result.type.should eq(Parser.type("ForceByReference"))
        result.type_name.should eq("ForceByReference")
        result.reference.should eq(false)
        result.pointer.should eq(0)
        result.conversion.should eq(nil)
      end
    end
  end

  describe "#generate_method_name" do
    it "handles a constructor" do
      m = Parser.method("", "Foo", Parser.void_type, Parser::Method::Type::Constructor)
      subject.generate_method_name(m, "Foo", "self").should eq "new (UseGC) Foo"
    end

    it "handles a copy-constructor" do
      m = Parser.method("", "Foo", Parser.void_type, Parser::Method::Type::CopyConstructor)
      subject.generate_method_name(m, "Foo", "self").should eq "new (UseGC) Foo"
    end

    it "handles a constructor with copied structure" do
      m = Parser.method("", "Copied", Parser.void_type, Parser::Method::Type::Constructor)
      subject.generate_method_name(m, "Copied", "self").should eq "Copied"
    end

    it "handles a copy-constructor with copied structure" do
      m = Parser.method("", "Copied", Parser.void_type, Parser::Method::Type::CopyConstructor)
      subject.generate_method_name(m, "Copied", "self").should eq "Copied"
    end

    it "handles member method" do
      m = Parser.method("the_func", "Foo", Parser.void_type, Parser::Method::Type::MemberMethod)
      subject.generate_method_name(m, "Foo", "me").should eq "me->the_func"
    end

    it "handles signal" do
      m = Parser.method("the_func", "Foo", Parser.void_type, Parser::Method::Type::Signal)
      subject.generate_method_name(m, "Foo", "me").should eq "me->the_func"
    end

    it "handles operator" do
      m = Parser.method("the_func", "Foo", Parser.void_type, Parser::Method::Type::Operator)
      subject.generate_method_name(m, "Foo", "me").should eq "me->the_func"
    end

    it "handles static method" do
      m = Parser.method("some_static", "Foo", Parser.void_type, Parser::Method::Type::StaticMethod)
      subject.generate_method_name(m, "Foo", "me").should eq "Foo::some_static"
    end
  end

  describe "#argument_name" do
    context "on a non-empty name" do
      it "returns the name" do
        subject.argument_name(Parser.argument("stuff", "int"), 3).should eq "stuff"
      end
    end

    context "on an empty name" do
      it "returns a generated name" do
        subject.argument_name(Parser.argument("", "int"), 3).should eq "unnamed_arg_3"
      end
    end
  end
end
