require "./type_helper"
require "./crystal/*"

module Bindgen
  # Functionality specific to the Crystal language.  Used by processors and
  # generators.
  module Crystal
    # All Crystal keywords
    KEYWORDS = %w[
      def if else elsif end true false class module include
      extend while until nil do yield return unless next break
      begin lib fun struct union enum macro out require
      case when select then of abstract rescue ensure is_a? alias
      pointerof sizeof instance_sizeof as as? typeof
      super private protected asm uninitialized nil?
    ]

    # Built-in types.  Includes Bindgen helper types.  This is not meant to be
    # an exhaustive list.  It needs to be maintained though to allow
    # `Processor::SanityCheck` to check type-reachability of Crystal types in
    # the resulting Crystal output.
    BUILTIN_TYPES = %w[
      Char String Array Hash
      Bool
      Void Nil
      Int Int8 Int16 Int32 Int64 UInt8 UInt16 UInt32 UInt64
      Float Float32 Float64
      Pointer Slice Bytes
      URI
      Time Time::Span
      Enumerable Iterable Indexable

      CrystalString CrystalProc
    ]
  end
end
