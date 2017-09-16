module Bindgen
  # Helper containing the default configuration variables.
  #
  # These include:
  # 1. Everything in `ENV` verbatim.
  # 2. `architecture` one of `aarch64`, `arm`, `armhf`, `i686`, `x86_64`
  # 3. `os` one of `darwin`, `freebsd`, `linux`, `openbsd`, `unix`, `windows`
  # 4. `libc` one of `gnu`, `musl`
  # 5. `pointersize` one of `32`, `64`
  # 6. `endian` one of `big`, `little`
  #
  # When requiring `bindgen`, e.g. to enhance it with custom processors, you
  # can add custom defaults by modifying `.builtin` directly.  This has to be
  # done early, before the configuration file itself is read.
  module Variables
    {% begin %}
    # Built-in variables.
    class_getter builtin = {
      # Hack, Crystal doesn't like a NEWLINE here.
      "architecture" => "" \
        {% if flag?(:aarch64) %} "aarch64",
        {% elsif flag?(:arm) %} "arm",
        {% elsif flag?(:armhf) %} "armhf",
        {% elsif flag?(:i686) %} "i686",
        {% elsif flag?(:x86_64) %} "x86_64",
        {% else %} "unknown",
        {% end %}

      "libc" => "" \
        {% if flag?(:gnu) %} "gnu",
        {% elsif flag?(:musl) %} "musl",
        {% else %} "unknown",
        {% end %}

      "os" => "" \
        {% if flag?(:darwin) %} "darwin",
        {% elsif flag?(:freebsd) %} "freebsd",
        {% elsif flag?(:linux) %} "linux",
        {% elsif flag?(:openbsd) %} "openbsd",
        {% elsif flag?(:unix) %} "unix",
        {% elsif flag?(:windows) %} "windows",
        {% else %} "unknown",
        {% end %}

      "pointersize" => (sizeof(Void*) * 8).to_s,
      "endian" => (Bytes[ 0x12, 0x34 ].to_unsafe.as(UInt16*).value == 0x1234) ? "big" : "little",
    }
    {% end %}

    # Returns a hash of variables for a `Parser`.
    def self.build(additional = nil) : ConfigReader::VariableHash
      hsh = @@builtin.dup

      ENV.each do |key, value| # Make ENV available
        hsh[key] = value
      end

      hsh.merge(additional) if additional
      hsh
    end
  end
end
