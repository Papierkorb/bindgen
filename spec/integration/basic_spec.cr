require "./spec_helper"

describe "a basic C++ wrapper" do
  it "works" do
    build_and_run("basic") do
      it "supports static methods" do
        Test::AdderWrap.sum(4, 5).should eq(9)
      end

      it "supports member methods" do
        Test::AdderWrap.new(4).sum(5).should eq(9)
      end
    end
  end
end
