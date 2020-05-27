require "../../spec_helper"

private class MemoryLoader < Bindgen::ConfigReader::Loader
  def initialize(@files : Hash(String, String))
  end

  def load(base_file : String, dependency : String)
    key = "#{File.dirname(base_file)}/#{dependency}"
    {@files[key], key}
  end
end

private class YamlThing
  YAML.mapping(
    list: {type: Array(String), nilable: true},
    string: String,
    recurse: {type: YamlThing, nilable: true},
  )

  def_equals_and_hash @list, @string, @recurse

  def initialize(@list, @string, @recurse = nil)
  end
end

private macro parse(content, type = YamlThing)
  {{ type }}.new(
    YAML::ParseContext.new,
    Bindgen::ConfigReader::Parser.new(
      # Using `vars` from the describe block
      evaluator: Bindgen::ConfigReader::ConditionEvaluator.new(vars),
      content: {{ content }},
      path: "root.yml",
      loader: MemoryLoader.new(files), # From the describe block
    ).parse.nodes.first,
  )
end

# Also tests InnerParser.
describe Bindgen::ConfigReader::Parser do
  # Used by `.parse`
  vars = {"foo" => "bar", "one" => "1", "version" => "1.0.0"}
  files = {} of String => String

  describe "normal yaml file" do
    it "works normally" do
      parse(%<
        list: [one, two]
        string: three
        recurse: { list: [four], string: five }
      >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
    end
  end

  describe "conditional feature" do
    context "single if" do
      it "takes the branch" do
        parse(%<
          list: [one, two]
          string: WRONG
          if_foo_is_bar:
            string: three
          recurse: { list: [four], string: five }
        >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end

      it "skips the branch" do
        parse(%<
          list: [one, two]
          string: three
          if_foo_is_something:
            string: WRONG
          recurse: { list: [four], string: five }
        >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end
    end

    context "if-else" do
      it "takes the if-branch" do
        parse(%<
          list: [one, two]
          if_foo_is_bar:
            string: three
          else:
            string: WRONG
          recurse: { list: [four], string: five }
        >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end

      it "skips the else-branch" do
        parse(%<
          list: [one, two]
          if_foo_isnt_bar:
            string: WRONG
          else:
            string: three
          recurse: { list: [four], string: five }
        >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end
    end

    context "if-elsif-else" do
      it "takes the if-branch" do
        parse(%<
          list: [one, two]
          if_foo_is_bar:
            string: three
          elsif_one_is_1:
            string: ELSIF WRONG
          else:
            string: ELSE WRONG
          recurse: { list: [four], string: five }
        >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end

      it "takes the elsif-branch" do
        parse(%<
          list: [one, two]
          if_foo_isnt_bar:
            string: IF WRONG
          elsif_one_is_1:
            string: three
          else:
            string: ELSE WRONG
          recurse: { list: [four], string: five }
        >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end

      it "takes the else-branch" do
        parse(%<
          list: [one, two]
          if_foo_isnt_bar:
            string: IF WRONG
          elsif_one_isnt_1:
            string: ELSIF WRONG
          else:
            string: three
          recurse: { list: [four], string: five }
        >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end
    end

    context "if-if-else" do
      it "takes the if-branch" do
        parse(%<
          list: [one, two]
          if_foo_is_bar:
            string: EARLY WRONG
          if_foo_is_bar:
            string: three
          else:
            string: WRONG
          recurse: { list: [four], string: five }
        >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end

      it "skips the else-branch" do
        parse(%<
          list: [one, two]
          if_foo_is_bar:
            string: EARLY WRONG
          if_foo_isnt_bar:
            string: WRONG
          else:
            string: three
          recurse: { list: [four], string: five }
        >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end
    end

    context "versions" do
      it "newer" do
        parse(%<
          list: [one, two]
          string: WRONG
          if_version_newer_0.9.9:
            string: three
          recurse: { list: [four], string: five }
        >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end

      it "newer equals" do
        parse(%<
          list: [one, two]
          string: WRONG
          if_version_newer_1.0.0:
            string: three
          recurse: { list: [four], string: five }
        >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end

      it "not newer" do
        parse(%<
          list: [one, two]
          string: three
          if_version_newer_1.0.1:
            string: WRONG
          recurse: { list: [four], string: five }
        >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end

      it "older" do
        parse(%<
          list: [one, two]
          string: WRONG
          if_version_older_1.0.1:
            string: three
          recurse: { list: [four], string: five }
        >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end

      it "older equals" do
        parse(%<
          list: [one, two]
          string: WRONG
          if_version_older_1.0.0:
            string: three
          recurse: { list: [four], string: five }
        >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end

      it "not older" do
        parse(%<
          list: [one, two]
          string: three
          if_version_older_0.9.9:
            string: WRONG
          recurse: { list: [four], string: five }
        >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end
    end

    context "fails" do
      it "for elsif without if" do
        expect_raises(Bindgen::ConfigReader::Parser::Error, /elsif-branch without if-branch/) do
          parse(%<
            foo: bar
            elsif_foo_is_bar: { }
          >, Hash(String, String))
        end
      end

      it "for else without if" do
        expect_raises(Bindgen::ConfigReader::Parser::Error, /else-branch without if-branch/) do
          parse(%<
            foo: bar
            else: { }
          >, Hash(String, String))
        end
      end
    end

    it "allows for intermixed values" do
      parse(%<
        if_foo_isnt_bar:
          string: WRONG
        list: [one, two]
        else:
          string: three
        recurse: { list: [four], string: five }
      >).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
    end
  end

  describe "dependency feature" do
    files["./some-list"] = %[{ list: [one, two] }]
    files["./some-string"] = %[{ string: three }]
    files["./recurse-1"] = %[
      list: [four]
      string: five
      recurse:
        <<: recurse-2
    ]
    files["./recurse-2"] = %[
      list: [six]
      string: seven
    ]
    files["./recurse-infinite"] = %[
      <<: recurse-infinite
    ]
    files["./subdir/first"] = %[{ <<: second }]
    files["./subdir/second"] = %[{ string: three }]

    describe "functionality" do
      it "injects into open mapping" do
        parse(%[
          <<: some-list
          string: three
          recurse: { list: [four], string: five }
        ]).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
      end

      it "supports recursion" do
        parse(%[
          list: [one, two]
          string: three
          recurse:
            <<: recurse-1
        ]).should eq(
          YamlThing.new(%w[one two], "three",
            YamlThing.new(%w[four], "five",
              YamlThing.new(%w[six], "seven")
            )
          )
        )
      end

      it "supports multiple injections" do
        parse(%[
          <<: some-list
          <<: some-string
          recurse:
            <<: recurse-1
        ]).should eq(
          YamlThing.new(%w[one two], "three",
            YamlThing.new(%w[four], "five",
              YamlThing.new(%w[six], "seven")
            )
          )
        )
      end

      it "supports sub-directories" do
        parse(%[
          list: [one]
          <<: subdir/first
        ]).should eq(YamlThing.new(%w[one], "three"))
      end
    end

    describe "error behaviour" do
      it "fails if recursion is too deep" do
        expect_raises(Bindgen::ConfigReader::Parser::Error, /dependency depth/) do
          parse(%[
            <<: recurse-infinite
          ])
        end
      end
    end
  end

  describe "conditional with dependency feature" do
    it "works" do
      parse(%[
        list: [one, two]
        if_foo_is_bar:
          <<: some-string
        recurse: { list: [four], string: five }
      ]).should eq(YamlThing.new(%w[one two], "three", YamlThing.new(%w[four], "five")))
    end
  end
end
