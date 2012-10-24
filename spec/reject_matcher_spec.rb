describe "RejectMatcher" do
  MemoryFileWrapper = Rake::Pipeline::SpecHelpers::MemoryFileWrapper

  let(:input_files) {
    [
      MemoryFileWrapper.new("/path/to/input", "ember.js", "UTF-8"),
      MemoryFileWrapper.new("/path/to/input", "jquery.js", "UTF-8")
    ]
  }
 
  it "accepts a string to match against" do
    pipeline = Rake::Pipeline::RejectMatcher.new
    pipeline.glob = /jquery/
    pipeline.output_root = "/path/to/output"
    pipeline.input_files = input_files

    pipeline.output_files.should == [MemoryFileWrapper.new("/path/to/input", "ember.js", "UTF-8")]
  end

  it "accepts a block to use" do
    pipeline = Rake::Pipeline::RejectMatcher.new
    pipeline.block = proc { |file|
      file.path =~ /ember/
    }

    pipeline.output_root = "/path/to/output"
    pipeline.input_files = input_files

    pipeline.output_files.should == [MemoryFileWrapper.new("/path/to/input", "jquery.js", "UTF-8")]
  end
end
