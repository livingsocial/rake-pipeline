describe "ConcatFilter" do
  MemoryFileWrapper = Rake::Pipeline::SpecHelpers::MemoryFileWrapper

  let(:input_files) {
    [
      MemoryFileWrapper.new("/path/to/input", "javascripts/jquery.js", "UTF-8", "jQuery = {};"),
      MemoryFileWrapper.new("/path/to/input", "javascripts/sproutcore.js", "UTF-8", "SC = {};")
    ]
  }

  it "generates output" do
    filter = Rake::Pipeline::ConcatFilter.new { "application.js" }
    filter.file_wrapper_class = MemoryFileWrapper
    filter.output_root = "/path/to/output"
    filter.input_files = input_files

    filter.output_files.should == [MemoryFileWrapper.new("/path/to/output", "application.js", "BINARY")]

    tasks = filter.generate_rake_tasks
    tasks.each(&:invoke)

    file = MemoryFileWrapper.files["/path/to/output/application.js"]
    file.body.should == "jQuery = {};SC = {};"
    file.encoding.should == "BINARY"
  end

  it "accepts a string to use as the output file name" do
    filter = Rake::Pipeline::ConcatFilter.new("app.js")
    filter.file_wrapper_class = MemoryFileWrapper
    filter.output_root = "/path/to/output"
    filter.input_files = input_files
    filter.output_files.should == [MemoryFileWrapper.new("/path/to/output", "app.js", "BINARY")]
  end
end
