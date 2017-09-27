require "./spec_helper"

describe "Qt-specific wrapper features" do
  it "works" do
    build_and_run("qt") do
      context "Signal connection" do
        it "creates a on_X method" do
          subject = Test::SomeObject.new

          called = false
          subject.on_stuff_happened do
            called = true
          end

          called.should be_true
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
