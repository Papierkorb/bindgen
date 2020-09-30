require "./spec_helper"

describe "container instantiation feature" do
  it "works" do
    build_and_run("containers") do
      context "sequential container" do
        it "works with explicitly instantiated container" do
          Test::Containers.new.integers.to_a.should eq([1, 2, 3])
        end

        it "works with auto instantiated container (result)" do
          Test::Containers.new.strings.to_a.should eq(["One", "Two", "Three"])
        end

        it "works with auto instantiated container (argument)" do
          list = [1.5, 2.5]
          Test::Containers.new.sum(list).should eq(4.0)
        end

        it "works with nested containers" do
          Test::Containers.new.grid.to_a.map(&.to_a).should eq([[1, 4], [9, 16]])
        end
      end
    end
  end
end
