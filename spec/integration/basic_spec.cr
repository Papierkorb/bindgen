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

      context "argument-less default constructor" do
        it "is generated if class is default-constructible" do
          {{
            Test::ImplicitConstructor.methods.any? do |m|
              m.name == "initialize" && m.args.empty?
            end
          }}.should be_true
        end

        it "is omitted if class is not default-constructible" do
          {{
            Test::PrivateConstructor.methods.any? do |m|
              m.name == "initialize" && m.args.empty?
            end
          }}.should be_false
          {{
            Test::DeletedConstructor.methods.any? do |m|
              m.name == "initialize" && m.args.empty?
            end
          }}.should be_false
        end
      end

      context "crystal wrapper features" do
        it "adds `#initialize(unwrap: Binding::T*)`" do
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

        it "adds `#initialize(*, ...)` for aggregate types" do
          {{
            Test::Aggregate.methods.any? do |m|
              m.name == "initialize" && \
                m.splat_index == 0 && \
                m.args.map(&.name.stringify) == ["", "x", "y", "z"]
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
      end

      it "returns a void pointer" do
        subject = Test::TypeConversion.new
        subject.void_pointer.address.should eq(0x11223344)
      end
    end
  end
end
