require "tempfile"
require "json"
require "yaml"
require "set"

require "./bindgen/generator"
require "./bindgen/call_analyzer/helper"
require "./bindgen/call_analyzer/cpp_methods"
require "./bindgen/call_analyzer/crystal_methods"
require "./bindgen/call_generator/helper"
require "./bindgen/call_generator/cpp_methods"
require "./bindgen/call_generator/crystal_methods"
require "./bindgen/**"

if ARGV.empty? || { "-h", "--help", "help" }.includes?(ARGV.first)
  puts "bindgen - Wrapper generator for C++ to Crystal."
  puts "  Usage: #{$0} [configuration yaml]"
  puts "See https://github.com/Papierkorb/bindgen for further information."
  exit 1
end

config = Bindgen::Configuration.from_yaml File.read(ARGV.first)
tool = Bindgen::Tool.new(config)
tool.run!
