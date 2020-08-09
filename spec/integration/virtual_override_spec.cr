require "./spec_helper"

describe "C++ virtual overriding from Crystal feature" do
  it "works" do
    build_and_run("virtual_override") do
      # Test inheriting from abstract class
      class NameThing < Test::AbstractThing
        def name : UInt8*
          "NameThing".to_unsafe
        end
      end

      # Test inheriting from non-abstract, multiple-inheritance class
      class Thing < Test::Subclass
        def name : UInt8*
          "Thing".to_unsafe
        end

        def calc(a, b)
          a - b
        end
      end

      # Test calling superclass method from overridden method
      class OverrideThing < Test::Base
        def calc(a, b)
          superclass.calc(a, b) ** 2
        end
      end

      class SubOverrideThing < Test::Subclass
        def calc(a, b)
          superclass.calc(a, b) ** 2
        end
      end

      context "non-abstract base-class" do
        it "overrides virtual method" do
          Thing.new.calc(10, 4).should eq(10 - 4)
        end

        it "overrides pure method" do
          String.new(Thing.new.name).should eq("Thing")
        end

        it "can call non-overriden virtual method" do
          Thing.new.random_number.should eq(4)
        end

        it "can call non-virtual method" do
          Thing.new.normal_method.should eq(1)
        end

        it "allows calling Crystal overrides from C++" do
          Thing.new.call_virtual(7, 6).should eq(1)
        end

        it "can call superclass method from overridden method" do
          OverrideThing.new.calc(10, 4).should eq(196)
          SubOverrideThing.new.calc(10, 4).should eq(1600)
        end

        # TODO: This fails!
        pending "can call method of second base" do
          # Thing.new.normal_method_in_abstract_thing.should eq(1)
        end

        it "auto wraps into an instance" do
          thing = Thing.new
          base = thing.belong_to_us
          base.should be_a(Test::Base)
          base.calc(4, 5).should eq(-1)
        end
      end

      context "abstract base-class" do
        it "can call overriden pure method" do
          String.new(NameThing.new.name).should eq("NameThing")
        end

        it "can call a member method" do
          NameThing.new.normal_method_in_abstract_thing.should eq(1)
        end

        it "auto wraps into an instance" do
          thing = NameThing.new
          abstract_base = thing.itself
          abstract_base.should be_a(Test::AbstractThing)
          String.new(abstract_base.name).should eq("NameThing")
        end
      end
    end
  end
end
