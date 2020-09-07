require "./spec_helper"

describe "a basic C++ wrapper" do
  it "works" do
    build_and_run("basic") do
      context "core functionality" do
        it "supports static methods" do
          Test::AdderWrap.sum(4, 5).should eq(9)
        end

        it "supports member methods" do
          Test::AdderWrap.new(4).sum(5).should eq(9)
        end
      end

      context "if class has implicit default constructor" do
        it "has a default constructor" do
          Test::ImplicitConstructor.new.it_works.should eq(1)
        end
      end

      context "crystal wrapper features" do
        it "adds #initialize(unwrap: Binding::T*)" do
          {{
            Test::AdderWrap.methods.any? do |m|
              m.name == "initialize" && \
                 m.args.size == 1 && \
                 m.args.any? do |a|
                  a.name.stringify == "unwrap"
                end
            end
          }}.should be_true
        end
      end

      context "method filtering" do
        methods = {{ Test::AdderWrap.methods.map(&.name.stringify) }}
        it "removes argument value type" do
          methods.includes?("ignoreByArgument").should be_false
        end
      end

      context "copy structure" do
        it "supports normal members" do
          Test::Binding::PlainStruct.new.x.should be_a(Int32)
          Test::Binding::PlainStruct.new.xp.should be_a(Pointer(Int32))
          Test::Binding::PlainStruct.new.vp.should be_a(Pointer(Void))
          Test::Binding::PlainStruct.new.vpp.should be_a(Pointer(Pointer(Void)))
        end

        it "supports array members" do
          Test::Binding::PlainStruct.new.y.should be_a(StaticArray(Int32, 4))
          Test::Binding::PlainStruct.new.yp.should be_a(StaticArray(Pointer(Int32), 6))
          Test::Binding::PlainStruct.new.z.should be_a(StaticArray(StaticArray(Int32, 16), 8))
        end
      end

      context "type decay matching" do
        it "supports specialized matching" do
          subject = Test::TypeConversion.new
          # `char *greet(const char *)` to `greet(String) : String`
          subject.greet("User").should eq("Hello User!")
        end

        it "supports base-type matching" do
          subject = Test::TypeConversion.new
          subject.next(5u8).should eq(6u8)
        end

        it "returns a void pointer" do
          subject = Test::TypeConversion.new
          subject.void_pointer.address.should eq(0x11223344)
        end
      end
    end
  end
end
