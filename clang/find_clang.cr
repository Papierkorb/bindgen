#!/usr/bin/env crystal run

# Helper script: Builds the `generated.hpp` containing the system include paths.
# Also outputs all LLVM and Clang libraries to link to.  Provides diagnostics
# to standard error.  Called by the `Makefile`.

require "json"
require "yaml"
require "../src/bindgen/util"
require "../src/bindgen/find_path"

UNAME_S = `uname -s`.chomp

def find_clang_binary : String?
  clang_find_config = Bindgen::FindPath::PathConfig.from_yaml <<-YAML
  kind: Executable
  try:
    - "clang++"
    - "clang++-*"
  search_paths:
    - /usr/bin/
  version:
    min: "4.0.0"
    command: "% --version"
    regex: "clang version ([0-9.]+)"
  YAML

  path_finder = Bindgen::FindPath.new(__DIR__)
  path_finder.find(clang_find_config)
end

def find_llvm_config_binary(search_paths = Array(String).new) : String?
  config_yaml = {
    "kind" => "Executable",
    "try"  => [
      "llvm-config",
    ],
    "version" => {
      "min"     => "4.0.0",
      "command" => "% --version",
      "regex"   => "([0-9.]+)",
    },
    "search_paths" => search_paths.map { |path| path.gsub(/(lib|include)$/, "bin") },
  }.to_yaml

  llvm_find_config = Bindgen::FindPath::PathConfig.from_yaml(config_yaml)

  path_finder = Bindgen::FindPath.new(__DIR__)
  path_finder.find(llvm_find_config)
end

def print_help_and_bail
  STDERR.puts <<-END
  You're missing the LLVM and/or Clang development libraries.
  Please install these:
    ArchLinux: pacman -S llvm clang gc libyaml
    Ubuntu: apt install clang-4.0 libclang-4.0-dev zlib1g-dev libncurses-dev libgc-dev llvm-4.0-dev libpcre3-dev
    CentOS: yum install crystal libyaml-devel gc-devel pcre-devel zlib-devel clang-devel
    openSUSE: zypper install llvm clang libyaml-devel gc-devel pcre-devel zlib-devel clang-devel ncurses-devel
    Mac OS: brew install crystal bdw-gc gmp libevent libxml2 libyaml llvm

  If you've installed these in a non-standard location, do one of these:
    1) Make the CLANG environment variable point to your `clang++` executable
    2) Add the `clang++` executable to your PATH

  If your distro does not support static libraries like openSUSE then set env BINDGEN_DYNAMIC=1
  END

  exit 1
end

def log(message : String)
  STDERR.puts message
end

# Find clang++ binary, through user setting, or automatically.
if binary = ENV["CLANG"]?
  unless Process.find_executable(binary)
    print_help_and_bail
  end

  clang_binary = binary
elsif binary = find_clang_binary
  clang_binary = binary
else
  print_help_and_bail
end

STDERR.puts "Using clang binary #{clang_binary.inspect}"

# Ask clang the paths it uses.
output = `#{clang_binary} -### #{__DIR__}/src/bindgen.cpp 2>&1`.lines

if output.size < 2 # Sanity check
  STDERR.puts "Unexpected output: Expected at least two lines."
  exit 1
end

# Shell-split
def shell_split(line : String)
  list = [] of String
  skip_next = false
  in_string = false
  offset = 0

  # Parse string
  line.each_char_with_index do |char, idx|
    if skip_next
      skip_next = false
      next
    end

    case char
    when '\\' # Escape character
      skip_next = true
    when ' ' # Split character
      unless in_string
        list << line[offset...idx]
        offset = idx + 1
      end
    when '"' # String marker
      in_string = !in_string
    end
  end

  list.reject(&.empty?).map do |x|
    # Remove surrounding double-quotes
    if x.starts_with?('"') && x.ends_with?('"')
      x[1..-2]
    else
      x
    end
  end
end

# Untangle the output
raw_cppflags = output[-2].gsub(/^\s+"|\s+"$/, "")
raw_ldflags = output[-1].gsub(/^\s+"|\s+"$/, "")

cppflags = raw_cppflags.split(/"\s+"/)
  .concat(shell_split(ENV.fetch("CPPFLAGS", "")))
  .uniq
ldflags = raw_ldflags.split(/"\s+"/)
  .concat(shell_split(ENV.fetch("LDFLAGS", "")))
  .uniq

#
system_includes = [] of String
system_libs = [] of String

# Interpret the argument lists
flags = cppflags + ldflags
index = 0
while index < flags.size
  case flags[index]
  when "-internal-isystem"
    system_includes << flags[index + 1]
    index += 1
  when "-resource-dir" # Find paths on Ubuntu
    resource_dir = flags[index + 1]
    system_includes << File.expand_path("#{resource_dir}/../../../include")
    index += 1
  when "-lto_library"
    to_library = flags[index + 1]
    system_libs << to_library.split("/lib/")[0] + "/lib/"
    index += 1
  when /^-L/
    l = flags[index][2..-1]
    l += "/" if l !~ /\/$/
    system_libs << l
  end

  index += 1
end

# Clean libs
system_libs.uniq!
system_libs.map! { |path| File.expand_path(path.gsub(/\/$/, "")) }
system_includes.uniq!
system_includes.map! { |path| File.expand_path(path.gsub(/\/$/, "")) }

# Generate the output header file.  This will be accessed from the clang tool.
output_path = "#{__DIR__}/include/generated.hpp"
output_code = String.build do |b|
  b.puts "// Generated by #{__FILE__}"
  b.puts "// DO NOT CHANGE"
  b.puts
  b.puts "#define BG_SYSTEM_INCLUDES { #{system_includes.map(&.inspect).join(", ")} }"
end

# Only write if there's a change.  Else we break make's dependency caching and
# constantly rebuild everything.
if !File.exists?(output_path) || File.read(output_path) != output_code
  File.write(output_path, output_code)
end

# Find all LLVM and clang libraries, and link to all of them.  We don't need
# all of them - Which totally helps with keeping linking times low.
def find_libraries(paths, prefix)
  if ENV.fetch("BINDGEN_DYNAMIC", "0") == "1"
    paths
      .flat_map { |path| Dir["#{path}/lib#{prefix}*.so"] }
      .map { |path| File.basename(path)[/^lib(.+)\.so$/, 1] }
      .uniq
  else
    paths
      .flat_map { |path| Dir["#{path}/lib#{prefix}*.a"] }
      .map { |path| File.basename(path)[/^lib([^.]+)\.a$/, 1] } # FIXME: this lead to crash for e.g. libclang_rt.msan_cxx-x86_64.a
      .uniq
  end
end

llvm_libs = find_libraries(system_libs, "LLVM")

if ARGV[0]? && ARGV[0] == "--llvm-libs"
  STDOUT << get_lib_args(llvm_libs).join(";")
  exit
end

clang_libs = find_libraries(system_libs, "clang")

if ARGV[0]? && ARGV[0] == "--clang-libs"
  STDOUT << get_lib_args(clang_libs).join(";")
  exit
end

# Try to provide the user with an error if we can't find it.
print_help_and_bail if llvm_libs.empty? || clang_libs.empty?

# Libraries must precede their dependencies. We can use the
# --start-group and --end-group wrappers in linux to get
# the correct order
def get_lib_args(libs_list)
  libs = Array(String).new
  if UNAME_S == "Darwin"
    libs.concat libs_list.map { |x| "-l#{x}" }
  else
    libs << "-Wl,--start-group"
    libs.concat libs_list.map { |x| "-l#{x}" }
    libs << "-Wl,--start-group"
  end
  libs
end

libs = get_lib_args(clang_libs)

libs += get_lib_args(llvm_libs)

includes = system_includes.map { |x| "-I#{File.expand_path(x)}" }

puts "CLANG_LIBS := " + libs.join(" ")
puts "CLANG_INCLUDES := " + includes.join(" ")
puts "CLANG_BINARY := " + clang_binary

# Find llvm config if we are using llvm
llvm_config_binary = find_llvm_config_binary(system_libs)

# Get flags from llvm
if !llvm_config_binary.nil? && File.exists?(llvm_config_binary)
  llvm_version = `#{llvm_config_binary} --version`.chomp

  puts "LLVM_CONFIG_BINARY := #{llvm_config_binary}"
  puts "LLVM_VERSION := " + llvm_version.split(/\./).first
  puts "LLVM_VERSION_FULL := #{llvm_version}"
  puts "LLVM_CXX_FLAGS := " + `#{llvm_config_binary} --cxxflags`.chomp
    .gsub(/-fno-exceptions/, "")
    .gsub(/-W[^alp].+\s/, "")
    .gsub(/\s+/, " ")
  puts "LLVM_LD_FLAGS := " + `#{llvm_config_binary} --ldflags`.chomp
    .gsub(/\s+/, " ")
end
