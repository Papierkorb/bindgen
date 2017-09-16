require "../spec_helper"

# Line prefixes to look out for in `.relocate_line_reports`
SPEC_METHODS = { "it(", "context(", "describe(" }

# Builds the project in configuration `NAME.yml`, expecting to yield the files
# `tmp/NAME.cr`, `tmp/NAME.cpp` and `tmp/NAME.o`.  Additionally, this macro will
# capture the block given to it and write it into `tmp/NAME_test.cr` within a
# small test skeleton.  Write normal `spec` it-tests in it.
#
# This is magic.  Have a look at the `*_spec.cr` files as sample code.
macro build_and_run(name, offset = __LINE__, source = __FILE__)
  build_and_run_impl({{ name }}, {{ yield.stringify }}, {{ offset }}, {{ source }})
end

# Embeds *code* into a `spec` skeleton.  Automatically requires the generated
# crystal wrapper of *name*.
private def embedded_test_code(name, code)
  <<-EOF
    require "spec"
    require "./#{name}"

    describe "Online test of #{name}" do
      #{code}
    end
  EOF
end

# Reads *code* line-wise, and inserts magic `#<loc:...>` comments before `spec`
# methods.  This will get the inner spec command to point to the *file* (The
# file the user wrote), instead of the generated source.
private def relocate_line_reports(code, file, base)
  String.build do |b|
    offset = 0

    code.each_line(chomp: false) do |line|
      offset += 1

      if SPEC_METHODS.any?{|x| line.starts_with?(x)}
        line_no = base + offset
        b << "#<loc:#{file.inspect},#{line_no},1>\n"
      end

      b << line
    end
  end
end

# Implementation helper for `.build_and_run`.
def build_and_run_impl(name, test_code, source_offset, source_file)
  config_file = "#{__DIR__}/#{name}.yml"
  test_file = "#{__DIR__}/tmp/#{name}_test.cr"

  # Write live test
  code = relocate_line_reports(test_code, source_file, source_offset)
  File.write(test_file, embedded_test_code(name, code))

  # Run bindgen tool
  config = Bindgen::Configuration.from_yaml File.read(config_file)
  tool = Bindgen::Tool.new(__DIR__, config, show_stats: false)

  status = nil
  command = "crystal run #{test_file}"
  output = IO::Memory.new

  # Run the tool and then the test program
  Dir.cd(__DIR__) do
    tool.run!.should eq(0)
    status = Process.run(command, shell: true, output: output, error: output)
  end

  raise "Status shouldn't be nil here" if status.nil?

  # On failure, print the output of the failed spec call.
  unless status.success?
    puts "#{">>> Output of failed spec:".colorize.mode(:bold)} #{name}.yml"
    STDERR.write output.to_slice
    puts "#{"<<< Failed spec command:".colorize.mode(:bold)} #{command}"

    raise Spec::AssertionFailed.new("Test for #{name}.yml failed, see above", source_file, source_offset)
  end

  # If we reach this line, the inner spec was successful - Yay!
end
