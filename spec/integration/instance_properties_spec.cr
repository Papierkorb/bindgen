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

        it "supports array members" do
          props = Test::Props.new(5, 8)

          v = props.v
          v.should be_a(Slice(Int32))
          v.size.should eq(4)
          v.read_only?.should be_false
          v[2].should eq(2001)
          v[2] = 0
          v[2].should eq(0)

          v2 = props.v2
          v2.should be_a(Slice(Int32[7][6]))
          v2.size.should eq(5)
          v2.read_only?.should be_false
          v2[4][3][2].should eq(2002)

          v_c = props.v_c
          v_c.read_only?.should be_true
          v_c[0].should eq(2003)

          props.v_ptr.should be_a(Slice(Int32*))
          props.v2_ptr.should be_a(Slice(Int32*[11]))
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

        it "is ignored for array members" do
          {% for member in %w[v= v2= v_c= v_ptr= v2_ptr=] %}
            {{ Test::Props.has_method?(member) }}.should be_false
          {% end %}
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
