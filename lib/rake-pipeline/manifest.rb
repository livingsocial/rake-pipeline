require 'json'

module Rake
  class Pipeline
    # A Manifest is a container for storing dynamic dependency information.
    # A {DynamicFileTask} will use a {Manifest} to keep track of its dynamic
    # dependencies. This allows us to avoid scanning a file for dynamic
    # dependencies if its contents have not changed.
    class Manifest
      attr_accessor :entries
      attr_accessor :manifest_file

      def initialize(manifest_file="manifest.json")
        @manifest_file ||= manifest_file
        @entries = {}
      end

      # Get the manifest off the file system, if it exists.
      def read_manifest
        @entries = File.file?(manifest_file) ? JSON.parse(File.read(manifest_file)) : {}

        # convert the manifest JSON into a Hash of ManifestEntry objects
        @entries.each do |file, raw|
          @entries[file] = Rake::Pipeline::ManifestEntry.from_hash(raw)
        end

        self
      end

      # Write a JSON representation of this manifest out to disk if we
      # have entries to save.
      def write_manifest
        unless @entries.empty?
          File.open(manifest_file, "w") do |file|
            file.puts JSON.generate(as_json)
          end
        end
      end

      # Convert this Manifest into a hash suitable for converting to
      # JSON.
      def as_json
        hash = {}

        @entries.each do |name, entry|
          hash[name] = entry.as_json
        end

        hash
      end

      # Look up an entry by filename.
      def [](key)
        @entries[key]
      end

      # Set an entry
      def []=(key, value)
        @entries[key] = value
      end

      def empty?
        entries.empty?
      end

      def files
        entries.inject({}) do |hash, pair| 
          file = pair.first
          entry = pair.last

          hash.merge!(file => entry.mtime)

          entry.deps.each_pair do |name, time| 
            hash.merge!(name => time)
          end

          hash
        end
      end
    end
  end
end
