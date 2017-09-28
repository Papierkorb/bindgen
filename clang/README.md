# Clang tool

This directory contains the `clang` based C++ parser.  Its job is to parse the
wanted files, and returning the found information as JSON formatted data.

This tool is executed by `Bindgen::Parser::Runner`.  Basically, it passes a ton
of arguments to this tool, and captures its standard output.

**Note**: If `clang++` is not in your `PATH`, provide the path to it through the
`CLANG` environment variable: `CLANG=/my/custom/clang++ make`

## Supported Clang versions

All versions above **4.0.0**.  Previous versions may or may not work.  Please
file a ticket if it fails with a supported version at
https://github.com/Papierkorb/bindgen/issues

## Build system

This tool uses a `Makefile`.  Just run `make` to build it.  Some `make`
implementations may call their binary differently.

### On Clang

The tool has one big flaw: It uses clang.  While clang is a good tool for this
job (I never tried the GCC equivalent for this), linking a tool using it isn't
much fun.  Second, we have to manually provide it with the system include paths.

For all of this, there's `find_clang.cr`.  It's a Crystal script figuring all of
this out.  It's used by the `Makefile`, and is supposed to be portable.

## Tips for direct usage

You can see the whole command line by setting `VERBOSE=1` before calling
bindgen: `$ VERBOSE=1 lib/bindgen/tool.sh my-config.yml`.

This will output a large JSON document without any spaces.  To format the
output, you can use the [jq tool](https://stedolan.github.io/jq/), like this:
`$ clang/bindgen ... | jq . > output.json` The "output.json" will now be
formatted.  If you want to use the less program instead of your editor, you can
get it to show formatting with highlighting:
`$ clang/bindgen ... | jq . -C | less -R`
