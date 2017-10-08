require "../spec_helper"

# Runs the clang tool on *cpp_code*, passing *arguments* to it.  All given
# key-word arguments are checked for equality in the returned JSON document.
# The check allows partial document comparisons.
def clang_tool(cpp_code, arguments, **checks)
  file = Tempfile.new("bindgen-clang-test")
  file.puts(cpp_code)
  file.flush

  tool = ENV["BINDGEN_BIN"]? || Bindgen::Parser::Runner::BINARY_PATH

  json_doc = `#{tool} #{file.path} #{arguments} -- -x c++ -std=c++11 -D__STDC_CONSTANT_MACROS -D__STDC_LIMIT_MACROS`

  doc = JSON.parse(json_doc)

  checks.each do |path, value|
    object = traverse_path(doc.raw, path)
    check_partial_value(object, value, path.to_s)
  end
rescue error
  pp doc.raw if doc
  raise error
ensure
  file.try(&.delete)
end

private def traverse_path(document, path)
  path.to_s.split('.').reduce(document) do |base, part|
    if index = part.to_i?
      base.as(Array)[index]
    else
      base.as(Hash)[part]
    end
  end
rescue error
  raise "Couldn't find path #{path}: #{error}"
end

private def check_partial_value(original, expected, path)
  case expected
  when Hash, NamedTuple
    hash = original.as?(Hash)
    raise "Expected a Hash, but got a #{expected.class}" if hash.nil?

    expected.each do |key, expected_child|
      check_partial_value(hash[key.to_s]?, expected_child, "#{path}.#{key}")
    end
  when Array, Tuple
    array = original.as?(Array)
    raise "Expected an Array, but got a #{expected.class}" if array.nil?

    if array.size != expected.size
      raise "Expected array of size #{expected.size}, but got a size of #{array.size} instead"
    end

    expected.each_with_index do |expected_child, index|
      check_partial_value(array[index], expected_child, "#{path}.#{index}")
    end
  else
    if original != expected
      raise "At #{path}: Expected #{expected.inspect}, got #{original.inspect}"
    end
  end
end
