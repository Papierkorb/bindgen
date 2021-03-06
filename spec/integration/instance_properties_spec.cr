require "./spec_helper"

describe "C++ instance properties" do
  it "works" do
    build_and_run("instance_properties") do
      # expose private methods as public ones
      class MyProps < Test::Props
        def x_prot
          super
        end

        def x_prot=(x)
          super
        end

        def y_prot
          super
        end
      end

      context "getter methods" do
        it "is generated for public members" do
          props = Test::Props.new(5, 8)
          props.x_pub.should eq(5)
          props.y_pub.should eq(8)

          {% begin %}
            {% method = Test::Props.methods.find &.name.== "x_pub" %}
            {{ method.visibility }}.should eq(:public)
            {% method = Test::Props.methods.find &.name.== "y_pub" %}
            {{ method.visibility }}.should eq(:public)
          {% end %}
        end

        it "is generated for protected members" do
          props = MyProps.new(5, 8)
          props.x_prot.should eq(105)
          props.y_prot.should eq(108)

          {% begin %}
            {% method = Test::Props.methods.find &.name.== "x_prot" %}
            {{ method.visibility }}.should eq(:private)
            {% method = Test::Props.methods.find &.name.== "y_prot" %}
            {{ method.visibility }}.should eq(:private)
          {% end %}
        end

        it "is ignored for private members" do
          {{ Test::Props.has_method?("x_priv") }}.should be_false
          {{ Test::Props.has_method?("y_priv") }}.should be_false
        end

        it "supports pointer members" do
          position = Test::Props.new(5, 8).position_ptr
          position.should be_a(Test::Point)
          position.x.should eq(12)
          position.y.should eq(34)
        end

        it "supports class-type value members" do
          position = Test::Props.new(5, 8).position_val
          position.should be_a(Test::Point)
          position.x.should eq(13)
          position.y.should eq(35)
        end

        it "supports static members" do
          position = Test::Props.corner
          position.should be_a(Test::Point)
          position.x.should eq(800)
          position.y.should eq(600)

          position = Test::Props.origin
          position.should be_a(Test::Point)
          position.x.should eq(0)
          position.y.should eq(0)
        end

        it "ignores wrapped constants" do
          {{ Test::Point.class.has_method?("dimensions") }}.should be_false
          {{ Test::Props.class.has_method?("c_f32") }}.should be_false
          {{ Test::Props.class.has_method?("c_b") }}.should be_false
        end
      end

      context "static const members" do
        it "supports static constants with arithmetic initializers" do
          Test::Point::DIMENSIONS.should eq(2)
          Test::Point::DIMENSIONS.should be_a(Int32)
          Test::Props::C_F32.should eq(1.2_f32)
          Test::Props::C_F32.should be_a(Float32)
          Test::Props::C_B.should eq(true)
          Test::Props::C_B.should be_a(Bool)
        end
      end

      context "setter methods" do
        it "is generated for public members" do
          props = Test::Props.new(5, 8)
          props.x_pub = 7
          props.x_pub.should eq(7)

          {% begin %}
            {% method = Test::Props.methods.find &.name.== "x_pub=" %}
            {{ method.visibility }}.should eq(:public)
          {% end %}
        end

        it "is generated for protected members" do
          props = MyProps.new(5, 8)
          props.x_prot = 7
          props.x_prot.should eq(7)

          {% begin %}
            {% method = Test::Props.methods.find &.name.== "x_prot=" %}
            {{ method.visibility }}.should eq(:private)
          {% end %}
        end

        it "is ignored for private members" do
          {{ Test::Props.has_method?("x_priv=") }}.should be_false
        end

        it "is ignored for const members" do
          methods = {{ Test::Props.methods.map &.name.stringify }}
          methods.includes?("y_pub=").should be_false
          methods.includes?("y_prot=").should be_false
          methods.includes?("y_priv=").should be_false
        end

        it "supports pointer members" do
          props = Test::Props.new(5, 8)
          props.position_ptr = Test::Point.new(60, 61)
          got = props.position_ptr
          got.x.should eq(60)
          got.y.should eq(61)
        end

        it "supports class-type value members" do
          props = Test::Props.new(5, 8)
          props.position_val = Test::Point.new(60, 61)
          got = props.position_val
          got.x.should eq(60)
          got.y.should eq(61)
        end

        it "supports static members" do
          Test::Props.corner = Test::Point.new(1024, 768)
          got = Test::Props.corner
          got.should be_a(Test::Point)
          got.x.should eq(1024)
          got.y.should eq(768)
        end

        it "is ignored for static const members" do
          {{ Test::Point.class.has_method?("dimensions=") }}.should be_false
          {{ Test::Props.class.has_method?("origin=") }}.should be_false
          {{ Test::Props.class.has_method?("c_f32=") }}.should be_false
          {{ Test::Props.class.has_method?("c_b=") }}.should be_false
        end
      end

      context "C++ unions" do
        it "works" do
          u = Test::PlainUnion.new
          u.x = 123
          u.y.should eq(123.unsafe_as(Float32))
          u.y = 123_f32
          u.x.should eq(123_f32.unsafe_as(Int32))
        end
      end

      context "nested members" do
        it "supports direct members inside nested anonymous types" do
          {{ Test::Anonymous.has_method?("x0") }}.should be_true
          {{ Test::Anonymous.has_method?("x0=") }}.should be_true
        end

        it "supports public nested fields" do
          {% begin %}
            {% method = Test::Anonymous.methods.find &.name.== "x0" %}
            {{ method.visibility }}.should eq(:public)
            {% method = Test::Anonymous.methods.find &.name.== "x0=" %}
            {{ method.visibility }}.should eq(:public)
          {% end %}
        end

        it "supports public fields nested inside protected members" do
          {% begin %}
            {% method = Test::NestedProtected.methods.find &.name.== "x" %}
            {{ method.visibility }}.should eq(:private)
            {% method = Test::NestedProtected.methods.find &.name.== "x=" %}
            {{ method.visibility }}.should eq(:private)
          {% end %}
        end

        it "ignores public fields nested inside private members" do
          {{ Test::NestedPrivate.has_method?("x") }}.should be_false
          {{ Test::NestedPrivate.has_method?("x=") }}.should be_false
        end
      end

      context "YAML configuration" do
        it "supports `instance_variables: false`" do
          {{ Test::ConfigIgnoreAll.has_method?("a") }}.should be_false
          {{ Test::ConfigIgnoreAll.has_method?("b") }}.should be_false
        end

        it "can ignore individual properties" do
          {{ Test::ConfigIgnore.has_method?("a") }}.should be_false
          {{ Test::ConfigIgnore.has_method?("b") }}.should be_true
        end

        it "can rename property methods" do
          {{ Test::ConfigRename.has_method?("var") }}.should be_true
          {{ Test::ConfigRename.has_method?("m_i_var") }}.should be_false
          {{ Test::ConfigRename.has_method?("another_var") }}.should be_true
          {{ Test::ConfigRename.has_method?("m_i_another_var") }}.should be_false
          {{ Test::ConfigRename.has_method?("x") }}.should be_true
        end

        context "can mark a pointer member as nilable" do
          props = Test::ConfigNilable.new
          bool = uninitialized Bool
          point = Test::Point.new(3, 4)

          props.bool_ptr = pointerof(bool)
          props.bool_ptr.should eq(pointerof(bool))
          props.bool_ptr = nil
          props.bool_ptr.should eq(Pointer(Bool).null)

          props.point_ptr = point
          props.point_ptr.not_nil!.to_unsafe.should eq(point.to_unsafe)
          props.point_ptr = nil
          props.point_ptr.should eq(nil)
        end
      end
    end
  end
end
