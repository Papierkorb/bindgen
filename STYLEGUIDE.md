# Styleguide for Bindgen

Hello!  The binding generator, which is the primary work done, is a complex
piece of software.  So, please follow these few rules in your PRs:

1. *Every* method gets an at least short documetation.  This includes `private`
   methods.  Only exception: Single-functionality classes.
2. *Every* class gets an at least short documetation string.  No exceptions.
3. Recycle code by refactoring if needed.  Don't be over-DRY, but don't copy
   large swaths of code either.
4. Text in comments get a double-space after each sentence: `Hello.  Next
   sentence.`
5. Comments and docs end on column 80 - Always.  Try to keep code below 100
   chars, up to 120 chars is acceptable.
6. Feel free to add additional comments what the code is about to do, if it's
   not super obvious already.
7. I'd rather have a method too much than too few: Keep the indention level
   low.  A good candidate is splitting a method doing a complex operation over a
   list on each element.

Explanation of the method names in the generator classes:

* `generate_` generates a `String` (Or array of `String`), and returns it.
* `write_` writes data into the output, may return something.
* `compute_` generates something that may not be a string.
* `add_` is the only method that changes the state of the generator instance variables.
* Any other prefix is free to use in a sensible manner.

For the C++ part of the project, additionally:

1. Mimic the style already in-place around your code.  That's it.
