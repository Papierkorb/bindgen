require "./spec_helper"

describe "C-specific functionality" do
  it "works" do
    build_and_run("c_wrapper") do
      context "constants" do
        it "maps them into the target module" do
          Test::ONE.should eq(1)
          Test::TWO.should eq(2)
          Test::THREE.should eq("Three")
        end

        it "maps them into a new module" do
          Test::Foo::A.should eq("A")
          Test::Foo::B.should eq("B")
          Test::Foo::C.should eq("C")
        end
      end

      context "enums" do
        it "maps an enum type" do
          {{ Test::Things.ancestors.includes?(Enum) }}.should be_true
          Test::Things::ThingOne.value.should eq(1)
          Test::Things::ThingTwo.value.should eq(2)
          Test::Things::ThingThree.value.should eq(3)
        end

        it "defaults to Int32" do
          typeof(Test::Things::ThingOne.value).should eq(Int32)
        end

        it "maps a flags enum type" do
          {{ Test::Foo::Bar.ancestors.includes?(Enum) }}.should be_true
          Test::Foo::Bar::One.value.should eq(1)
          Test::Foo::Bar::Two.value.should eq(2)
          Test::Foo::Bar::Four.value.should eq(4)

          Test::Foo::Bar::None.value.should eq(0)
          Test::Foo::Bar::All.value.should eq(1 | 2 | 4)
        end

        it "uses the configured base type" do
          typeof(Test::Foo::Bar::One.value).should eq(UInt32)
        end
      end

      context "simple functions" do
        it "maps short-hand" do
          Test::Funcs.one.should eq(1)
        end

        it "maps through full name" do
          Test::Funcs.two.should eq(2)
        end

        it "maps short-hand with one capture group" do
          Test::Funcs::Thr.ee.should eq(3)
        end

        it "maps with one capture group" do
          Test::Funcs.four.should eq(4)
        end
      end

      context "multiple function matches" do
        it "maps with short-hand" do
          Test::Funcs::Calc.add(4, 3).should eq(7)
          Test::Funcs::Calc.sub(4, 3).should eq(1)
        end
      end

      context "functions with individual nesting" do
        it "maps them accordingly" do
          Test::Funcs::Increment.one(5).should eq(6)
          Test::Funcs::Decrement.one(5).should eq(4)
        end
      end
    end
  end
end
