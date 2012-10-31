require 'spec_helper'

describe Rake::Pipeline::ManifestEntry do
  let(:hash) do
    {
      "deps" => {
        "file.h" => 100,
        "other.h" => 100
      },
      "mtime" => 200
    }
  end

  subject {
    Rake::Pipeline::ManifestEntry.from_hash(hash)
  }

  describe "#from_hash" do
    it "creates a new ManifestEntry from a hash" do
      subject.should be_kind_of described_class
    end

    it "should leave mtimes have integers" do
      subject.mtime.should == 200
    end

    it "parses each time from the deps value into a Time" do
      subject.deps.each do |file, mtime|
        mtime.should == 100
      end
    end
  end

  describe "#as_json" do
    it "returns a hash representation of the entry for converting to json" do
      subject.as_json.should == {
        :deps => {
          "file.h" => 100,
          "other.h" => 100
        },
        :mtime => 200
      }
    end
  end
end

