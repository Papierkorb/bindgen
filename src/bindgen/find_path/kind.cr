module Bindgen
  class FindPath
    # Kinds of file that we can distinguish.
    enum Kind
      Directory
      File

      # Returns `true` only if *path* exists and is of kind `self`.
      def exists?(path : String) : Bool
        case self
        when Directory then ::Dir.exists?(path)
        when File then ::File.file?(path)
        else raise "BUG: Unreachable!"
        end
      end
    end
  end
end
