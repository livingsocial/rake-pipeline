require 'spec_helper'

describe Rake::Pipeline::Manifest do
  before do
    # ensure all our date/time conversions happen in UTC.
    ENV['TZ'] = 'UTC'
  end

  let(:manifest_file) { "#{tmp}/manifest.json" }

  let(:json) { <<-JSON }
{
  "file.h": {
    "deps": {
      "other.h": "2000-01-01 00:00:00 +0000"
    },
    "mtime":"2000-01-01 00:00:00 +0000"
  }
}
  JSON

  let(:entries_hash) do
    {
      "file.h" => Rake::Pipeline::ManifestEntry.from_hash({
        "deps" => {
          "other.h" => "2000-01-01 00:00:00 +0000"
        },
        "mtime" => "2000-01-01 00:00:00 +0000"
      })
    }
  end

  subject do
    Rake::Pipeline::Manifest.new(manifest_file)
  end

  describe "#write_manifest" do
    before do
      subject.entries = entries_hash
      rm_rf manifest_file
    end

    it "writes a manifest json file to disk" do
      subject.write_manifest

      File.exist?(manifest_file).should be_true
      JSON.parse(File.read(manifest_file)).should == JSON.parse(json)
    end

    it "writes nothing if it's empty" do
      subject.entries = {}
      subject.write_manifest
      File.exist?(manifest_file).should be_false
    end
  end

  describe "#read_manifest" do
    before do
      File.open(manifest_file, 'w') { |f| f.puts json }
    end

    it "reads a manifest json file from disk" do
      subject.read_manifest
      subject.entries.should == entries_hash
    end
  end
end
