class Rake::Pipeline
  module SpecHelpers
    class MemoryManifest
      def initialize
        @entries = {}
      end

      # Look up an entry by filename.
      def [](key)
        @entries[key]
      end

      # Set an entry
      def []=(key, value)
        @entries[key] = value
      end
    end
  end
end
