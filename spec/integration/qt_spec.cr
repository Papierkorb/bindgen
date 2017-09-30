require "./spec_helper"

describe "Qt-specific wrapper features" do
  it "works" do
    build_and_run("qt") do
      context "signal behaviour" do
        it "creates a on_X method" do
          subject = Test::SomeObject.new

          called = false
          subject.on_stuff_happened do
            called = true
          end

          called.should be_true
        end

        context "private signals" do
          it "don't have an emission method" do
            {{ Test::SomeObject.methods.map(&.name.stringify) }}.includes?("private_signal").should be_false
          end

          it "have the connection method" do
            {{ Test::SomeObject.methods.map(&.name.stringify) }}.includes?("on_private_signal").should be_true
            {{ Test::SomeObject.methods.find(&.name.== "on_private_signal").args.size }}.should eq(0)
          end
        end
      end

      context "Q_GADGET behaviour" do
        it "removes the gadget checker" do
          {{ Test::SomeGadget.methods.map(&.name.stringify) }}.includes?("qt_check_for_QGADGET_macro").should be_false
        end
      end
    end
  end
end
