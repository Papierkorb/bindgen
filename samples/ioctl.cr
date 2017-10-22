# Sample code to bind libc's `ioctl()` function using bindgen.
# Build: $ ./build.sh ioctl.yml
# Run  : $ crystal ioctl.cr

# Require the generated bindings:
require "./binding/ioctl"

# And use the copied `Winsize` structure.  Copied structures end up in the
# `Binding` namespace, so they don't collide with wrapper classes:
size = Ioctl::Binding::Winsize.new

# Use ioctl() to tell us the terminal window size:
Ioctl.ioctl(STDOUT.fd, Ioctl::TIOCGWINSZ, pointerof(size));

# And output what we've got:
puts "Your terminal size is #{size.ws_col}x#{size.ws_row}."
