require "./spec_helper"

describe "copied structure functionality" do
  it "works" do
    build_and_run("copy_structs") do
      def instance_var_names(type : T) forall T
        {{ T.instance_vars.map(&.stringify) }}
      end

      context "core functionality" do
        it "supports structs" do
          subject = Test::Binding::Point.new
          instance_var_names(subject).should eq(%w{x y})
          subject.x.should be_a(Int32)
          subject.y.should be_a(Int32)
        end

        it "supports members of other copied structs" do
          subject = Test::Binding::Line.new
          instance_var_names(subject).should eq(%w{v1 v2})
          subject.v1.should be_a(Test::Binding::Point)
          subject.v2.should be_a(Test::Binding::Point)
        end

        # fixed on the c-arrays branch
        pending "supports pointers to other copied structs" do
          subject = Test::Binding::PolyLine.new
          subject.line.should eq(Pointer(Test::Binding::Line).null)
          subject.before.should eq(Pointer(Test::Binding::Line).null)
          subject.after.should eq(Pointer(Test::Binding::Line).null)
        end
      end

      context "nested types" do
        it "supports nested structs" do
          subject = Test::Binding::Nested.new
          subject.c.should be_a(Test::Binding::Nested_Inner2)
          instance_var_names(subject.c).should eq(%w{b})

          subject = Test::Binding::Nested_Inner.new
          instance_var_names(subject).should eq(%w{a})
        end

        it "supports nested anonymous structs" do
          subject = Test::Binding::Anonymous.new
          instance_var_names(subject).should eq(%w{x0 p0 p2})
          instance_var_names(subject.p0).should eq(%w{x1})
          instance_var_names(subject.p2).should eq(%w{x2 p1})
          instance_var_names(subject.p2.p1).should eq(%w{x3})
        end

        it "ignores inlined anonymous structs" do
          {{ Test::Binding.has_constant?("Anonymous_Unnamed0") }}.should be_false
          {{ Test::Binding.has_constant?("Anonymous_Unnamed0_Unnamed0") }}.should be_false
          {{ Test::Binding.has_constant?("Anonymous_Unnamed1_Unnamed0") }}.should be_false
        end

        it "ignores anonymous structs inside wrapped classes" do
          {{ Test::Binding.has_constant?("Wrapped_Unnamed0") }}.should be_false
        end
      end
    end
  end
end
