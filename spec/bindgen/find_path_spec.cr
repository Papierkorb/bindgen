require  "../spec_helper"

describe Bindgen::FindPath do
  root_dir = "#{__DIR__}/.." # spec/

  context "if all paths are found" do
    it "adds all variables and returns an empty array" do
      config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
      SUCCESS:
        try: [ "%/*" ]
        checks:
          - path: find_path_spec.cr
      SKIPPED:
        try: [ "WouldActuallyFail" ]
      NOT_SKIPPED:
        try: [ "%/**/*" ]
        checks:
          - path: checker_spec.cr
          - path: kind_spec.cr
      YAML

      vars = {
        "SKIPPED" => "Already-Set",
        "NOT_SKIPPED" => "", # Empty == nil
      }

      subject = Bindgen::FindPath.new(root_dir, vars)
      errors = subject.find_all!(config)

      errors.empty?.should be_true
      vars.should eq({
        "SUCCESS" => "#{root_dir}/bindgen",
        "SKIPPED" => "Already-Set",
        "NOT_SKIPPED" => "#{root_dir}/bindgen/find_path",
      })
    end
  end

  context "if a path was not found" do
    it "adds all other variables but returns the error array" do
      config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
      SUCCESS:
        try: [ "%/*" ]
        checks:
          - path: find_path_spec.cr
      THIS_FAILS:
        try: [ "ThisFails" ]
      YAML

      vars = { } of String => String
      subject = Bindgen::FindPath.new(root_dir, vars)
      errors = subject.find_all!(config)

      vars.should eq({ "SUCCESS" => "#{root_dir}/bindgen" })
      errors.size.should eq(1)
      error = errors.first

      error.variable.should eq("THIS_FAILS")
      error.config.should be(config["THIS_FAILS"])
    end
  end

  context "if the first tries fail" do
    it "tries the next one" do
      config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
      TEST:
        try:
          - "doesnt_exist/"
          - shell: "false"
          - "%"
          - "%/*"
        checks:
          - path: find_path_spec.cr
      YAML

      vars = { } of String => String

      subject = Bindgen::FindPath.new(root_dir, vars)
      errors = subject.find_all!(config)

      errors.empty?.should be_true
      vars.should eq({ "TEST" => "#{root_dir}/bindgen" })
    end
  end

  context "try: String" do
    it "has access to the environment" do
      config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
      PREVIOUS:  { try: [ "%/bindgen" ] }
      EXPANSION: { try: [ "%" ] }
      ENV_VAR:   { try: [ "{PREVIOUS}" ] }
      YAML

      vars = { } of String => String
      subject = Bindgen::FindPath.new(root_dir, vars)
      errors = subject.find_all!(config)

      errors.empty?.should be_true
      vars.should eq({
        "PREVIOUS" => "#{root_dir}/bindgen",
        "ENV_VAR" => "#{root_dir}/bindgen",
        "EXPANSION" => root_dir,
      })
    end
  end

  # These are (at least) UNIX specific, and probably fail on Windows.
  context "try: ShellTry" do
    it "has access to the environment" do
      config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
      PREVIOUS:
        try: [ "%/bindgen" ]
      EXPANSION:
        try: [ { shell: "echo '%'" } ]
      ENV_VAR:
        try: [ { shell: "echo '{PREVIOUS}'" } ]
      YAML

      vars = { } of String => String
      subject = Bindgen::FindPath.new(root_dir, vars)
      errors = subject.find_all!(config)

      errors.empty?.should be_true
      vars.should eq({
        "PREVIOUS" => "#{root_dir}/bindgen",
        "ENV_VAR" => "#{root_dir}/bindgen",
        "EXPANSION" => root_dir,
      })
    end

    context "the command fails" do
      it "fails the try" do
        config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
        FAILS: { try: [ { shell: "echo '/lib'; false" } ] }
        YAML

        vars = { } of String => String
        subject = Bindgen::FindPath.new(root_dir, vars)
        errors = subject.find_all!(config)

        vars.empty?.should be_true
        errors.size.should eq(1)

        error = errors.first
        error.variable.should eq("FAILS")
      end
    end

    context "the commands output fails the checks" do
      it "fails the try" do
        config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
        FAILS:
          try: [ { shell: "echo '%'" } ]
          checks:
            - path: doesnt_exist
        YAML

        vars = { } of String => String
        subject = Bindgen::FindPath.new(root_dir, vars)
        errors = subject.find_all!(config)

        vars.empty?.should be_true
        errors.size.should eq(1)

        error = errors.first
        error.variable.should eq("FAILS")
      end
    end

    context "no regex is set" do
      it "takes the first line" do
        config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
        TEST: { try: [ { shell: "echo -e '%\\\\nFooBar'" } ] }
        YAML

        vars = { } of String => String
        subject = Bindgen::FindPath.new(root_dir, vars)
        errors = subject.find_all!(config)

        vars.should eq({ "TEST" => root_dir })
        errors.empty?.should be_true
      end

      it "fails if the first line is empty" do
        config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
        TEST: { try: [ { shell: "echo" } ] }
        YAML

        vars = { } of String => String
        subject = Bindgen::FindPath.new(root_dir, vars)
        errors = subject.find_all!(config)

        vars.empty?.should be_true
        errors.size.should eq(1)

        error = errors.first
        error.variable.should eq("TEST")
      end
    end

    context "if regex is set" do
      context "and has a capture group" do
        it "takes the capture group" do
          config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
          TEST:
            try:
              - shell: "echo -e 'Header\\\\nDIR=%\\\\nFooter'"
                regex: "^DIR=(.*)"
          YAML

          vars = { } of String => String
          subject = Bindgen::FindPath.new(root_dir, vars)
          errors = subject.find_all!(config)

          vars.should eq({ "TEST" => root_dir })
          errors.empty?.should be_true
        end

        it "fails if the capture group is empty" do
          config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
          TEST:
            try:
              - shell: "echo -e 'Header\\\\nDIR=%\\\\nFooter'"
                regex: "DIR=()"
          YAML

          vars = { } of String => String
          subject = Bindgen::FindPath.new(root_dir, vars)
          errors = subject.find_all!(config)

          vars.empty?.should be_true
          errors.size.should eq(1)

          error = errors.first
          error.variable.should eq("TEST")
        end
      end

      context "has no capture group" do
        it "takes the matched part" do
          config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
          TEST:
            try:
              - shell: "echo -e 'Header\\\\n%\\\\nFooter'"
                regex: "^.*/spec/.*$"
          YAML

          vars = { } of String => String
          subject = Bindgen::FindPath.new(root_dir, vars)
          errors = subject.find_all!(config)

          vars.should eq({ "TEST" => root_dir })
          errors.empty?.should be_true
        end

        it "fails if the matched part is empty" do
          config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
          TEST:
            try:
              - shell: "echo -e 'Something\\\\nDIR=%'"
                regex: ""
          YAML

          vars = { } of String => String
          subject = Bindgen::FindPath.new(root_dir, vars)
          errors = subject.find_all!(config)

          vars.empty?.should be_true
          errors.size.should eq(1)

          error = errors.first
          error.variable.should eq("TEST")
        end
      end

      context "does not match" do
        it "fails" do
          config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
          TEST:
            try:
              - shell: "echo -e 'Something\\\\nDIR=%'"
                regex: "^/doesnt_exist/.*"
          YAML

          vars = { } of String => String
          subject = Bindgen::FindPath.new(root_dir, vars)
          errors = subject.find_all!(config)

          vars.empty?.should be_true
          errors.size.should eq(1)

          error = errors.first
          error.variable.should eq("TEST")
        end
      end
    end
  end

  context "file kinds" do
    it "finds a file" do
      config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
      TEST:
        kind: File
        try: [ "%/bindgen", "%/spec_helper.cr" ]
      YAML

      vars = { } of String => String
      subject = Bindgen::FindPath.new(root_dir, vars)
      errors = subject.find_all!(config)

      errors.empty?.should be_true
      vars.should eq({ "TEST" => "#{root_dir}/spec_helper.cr" })
    end

    it "finds a directory" do
      config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
      TEST:
        kind: Directory
        try: [ "%/spec_helper.cr", "%/bindgen" ]
      YAML

      vars = { } of String => String
      subject = Bindgen::FindPath.new(root_dir, vars)
      errors = subject.find_all!(config)

      errors.empty?.should be_true
      vars.should eq({ "TEST" => "#{root_dir}/bindgen" })
    end

    it "finds an executable file" do
      config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
      TEST:
        kind: Executable
        try:
          - "%/spec_helper.cr"
          - "%/bindgen"
          - "%/bindgen/find_path/fixture/tool"
      YAML

      vars = { } of String => String
      subject = Bindgen::FindPath.new(root_dir, vars)
      errors = subject.find_all!(config)

      errors.empty?.should be_true
      vars.should eq({ "TEST" => "#{root_dir}/bindgen/find_path/fixture/tool" })
    end
  end

  context "search paths feature" do
    it "supports them" do
      config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
      TEST:
        kind: File
        try: [ "bindgen", "spec_helper.cr" ]
        search_paths: [ "..", "%" ]
      YAML

      vars = { } of String => String
      subject = Bindgen::FindPath.new(root_dir, vars)
      errors = subject.find_all!(config)

      errors.empty?.should be_true
      vars.should eq({ "TEST" => "#{root_dir}/spec_helper.cr" })
    end

    it "works with sub-directories" do
      config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
      TEST:
        kind: File
        try: [ "spec/bindgen", "spec/spec_helper.cr" ]
        search_paths: [ "%/.." ]
      YAML

      vars = { } of String => String
      subject = Bindgen::FindPath.new(root_dir, vars)
      errors = subject.find_all!(config)

      errors.empty?.should be_true
      vars.should eq({ "TEST" => "#{root_dir}/../spec/spec_helper.cr" })
    end

    it "defaults to PATH for executables" do
      config = Bindgen::FindPath::Configuration.from_yaml <<-YAML
      TEST:
        kind: Executable
        try: [ "DOESNT_EXIST_HOPEFULLY", "ls", "cmd.exe" ]
      YAML

      vars = { } of String => String
      subject = Bindgen::FindPath.new(root_dir, vars)
      errors = subject.find_all!(config)

      errors.empty?.should be_true
      {% if flag?(:windows) %}
        vars.should eq({ "TEST" => Process.find_executable("cmd") })
      {% else %}
        vars.should eq({ "TEST" => Process.find_executable("ls") })
      {% end %}
    end
  end

  context "Dir.glob bug" do
    it "fails if #5118 has been fixed" do
      # TODO: Remove this spec once it fails and the issue has been fixed.
      # See https://github.com/crystal-lang/crystal/issues/5118
      # See Bindgen::FindPath#run_path_try(path : String, ...)

      expect_raises(ArgumentError, /empty glob pattern/i){ Dir["/"] }
      Dir["/usr/.."].should eq([ ] of String)
      Dir["/usr/."].should eq([ ] of String)
      Dir["*/.."].should eq([ ] of String)
      Dir["*/../*"].should eq([ ] of String)
    end
  end
end
