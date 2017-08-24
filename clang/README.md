# Clang tool

This directory contains the `clang` based C++ parser.  Its job is to parse the
wanted files, and returning the found information as JSON formatted data.

This tool is executed by `Bindgen::Parser::Runner`.  Basically, it passes a ton
of arguments to this tool, and captures its standard output.

## Tips for direct usage

You can see the whole command line by setting `VERBOSE=1` before calling
bindgen: `$ VERBOSE=1 lib/bindgen/tool.sh my-config.yml`.

This will output a large JSON document without any spaces.  To format the
output, you can use the [jq tool](https://stedolan.github.io/jq/), like this:
`$ clang/bindgen ... | jq . > output.json` The "output.json" will now be
formatted.  If you want to use the less program instead of your editor, you can
get it to show formatting with highlighting:
`$ clang/bindgen ... | jq . -C | less -R`
