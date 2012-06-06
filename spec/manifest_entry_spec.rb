require 'spec_helper'

describe Rake::Pipeline::ManifestEntry do
  before do
    # ensure all our date/time conversions happen in UTC.
    ENV['TZ'] = 'UTC'
  end

  let(:hash) do
    {
      "deps" => {
        "file.h" => "2001-01-01 00:00:00 +0000",
        "other.h" => "2001-01-01 00:00:00 +0000"
      },
      "mtime" => "2000-01-01 00:00:00 +0000"
    }
  end

  subject {
    Rake::Pipeline::ManifestEntry.from_hash(hash)
  }

  describe "#from_hash" do
    it "creates a new ManifestEntry from a hash" do
      subject.should be_kind_of described_class
    end

    it "parses mtime value into a Time" do
      subject.mtime.should == Time.utc(2000)
    end

    it "parses each time from the deps value into a Time" do
      subject.deps.each do |file, mtime|
        mtime.should == Time.utc(2001)
      end
    end
  end

  describe "#as_json" do
    it "returns a hash representation of the entry for converting to json" do
      subject.as_json.should == {
        :deps => {
          "file.h" => Time.utc(2001),
          "other.h" => Time.utc(2001),
        },
        :mtime => Time.utc(2000)
      }
    end
  end
end

