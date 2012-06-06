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

      # Write the manifest out to disk if we have entries to save.
      def write_manifest
        unless @entries.empty?
          File.open(manifest_file, "w") do |file|
            file.puts JSON.generate(as_json)
          end
        end
      end

      def as_json
        hash = {}

        @entries.each do |name, entry|
          hash[name] = entry.as_json
        end

        hash
      end

      def [](key)
        @entries[key]
      end

      def []=(key, value)
        @entries[key] = value
      end
    end
  end
end
