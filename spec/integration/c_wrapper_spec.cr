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
    end
  end
end
