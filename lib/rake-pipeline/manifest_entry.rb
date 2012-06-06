module Rake
  class Pipeline
    class ManifestEntry
      def self.from_hash(hash)
        entry = new

        entry.mtime = DateTime.parse(hash["mtime"]).to_time

        hash["deps"].each do |dep, time_string|
          entry.deps[dep] = DateTime.parse(time_string).to_time
        end

        entry
      end

      attr_accessor :deps, :mtime

      def initialize(deps={}, mtime=nil)
        @deps, @mtime = deps, mtime
      end

      def as_json
        { :deps => @deps, :mtime => @mtime }
      end

      def ==(other)
        mtime == other.mtime
        deps == other.deps
      end
    end
  end
end
