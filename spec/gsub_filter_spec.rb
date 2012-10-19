describe "GsubFilter" do
  MemoryFileWrapper = Rake::Pipeline::SpecHelpers::MemoryFileWrapper

  let(:input_files) {
    [
      MemoryFileWrapper.new("/path/to/input", "ember.js", "UTF-8", "Ember.assert"),
    ]
  }

  it "generates output" do
    filter = Rake::Pipeline::GsubFilter.new "Ember.assert", 'foo'
    filter.file_wrapper_class = MemoryFileWrapper
    filter.output_root = "/path/to/output"
    filter.input_files = input_files

    filter.output_files.should == [MemoryFileWrapper.new("/path/to/output", "ember.js", "UTF-8")]

    tasks = filter.generate_rake_tasks
    tasks.each(&:invoke)

    file = MemoryFileWrapper.files["/path/to/output/ember.js"]
    file.body.should == "foo"
  end

  it "accepts a block to use with gsub" do
    filter = Rake::Pipeline::GsubFilter.new "Ember.assert" do 
      "foo"
    end

    filter.file_wrapper_class = MemoryFileWrapper
    filter.output_root = "/path/to/output"
    filter.input_files = input_files

    filter.output_files.should == [MemoryFileWrapper.new("/path/to/output", "ember.js", "UTF-8")]

    tasks = filter.generate_rake_tasks
    tasks.each(&:invoke)

    file = MemoryFileWrapper.files["/path/to/output/ember.js"]
    file.body.should == "foo"
  end

  it "use the input name for output" do
    filter = Rake::Pipeline::GsubFilter.new
    filter.file_wrapper_class = MemoryFileWrapper
    filter.output_root = "/path/to/output"
    filter.input_files = input_files
    filter.output_files.should == [MemoryFileWrapper.new("/path/to/output", "ember.js", "UTF-8")]
  end
end
