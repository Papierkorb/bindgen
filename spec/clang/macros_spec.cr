require "./spec_helper"

describe "clang tool macros feature" do
  it "exports the macros" do
    clang_tool(
      %[
        #define THING_ONE 1
        #define THING_TWO 2
        #define ANOTHER 3
        #define NOT_EXPORTED 4
        #define ADD_ONE(x) (x + 1)
      ],
      "-m 'THING_.*|ANOTHER|ADD_ONE'",
      macros: [
        {
          name: "THING_ONE",
          isFunction: false,
          isVarArg: false,
          arguments: [ ] of String,
          value: "1",
        },
        {
          name: "THING_TWO",
          isFunction: false,
          isVarArg: false,
          arguments: [ ] of String,
          value: "2",
        },
        {
          name: "ANOTHER",
          isFunction: false,
          isVarArg: false,
          arguments: [ ] of String,
          value: "3",
        },
        {
          name: "ADD_ONE",
          isFunction: true,
          isVarArg: false,
          arguments: [ "x" ],
          value: "(x + 1)",
        },
      ]
    )
  end
end
