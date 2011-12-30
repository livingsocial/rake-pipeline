describe "OrderingConcatFilter" do
  MemoryFileWrapper = Rake::Pipeline::SpecHelpers::MemoryFileWrapper

  let(:input_files) {
    [
      MemoryFileWrapper.new("/path/to/input", "first.txt", "UTF-8", "FIRST"),
      MemoryFileWrapper.new("/path/to/input", "second.txt", "UTF-8", "SECOND"),
      MemoryFileWrapper.new("/path/to/input", "last.txt", "UTF-8", "LAST")
    ]
  }

  let(:output_files) {
    [
      MemoryFileWrapper.new("/path/to/output", "all.txt", "BINARY")
    ]
  }

  let(:output_file) {
    MemoryFileWrapper.files["/path/to/output/all.txt"]
  }

  def make_filter(ordering)
    filter = Rake::Pipeline::OrderingConcatFilter.new(ordering, "all.txt")
    filter.file_wrapper_class = MemoryFileWrapper
    filter.input_files = input_files
    filter.output_root = "/path/to/output"
    filter.rake_application = Rake::Application.new
    filter.generate_rake_tasks.each(&:invoke)
    filter
  end

  it "generates output" do
    filter = make_filter(["first.txt", "second.txt"])

    filter.output_files.should == output_files
    output_file.body.should == "FIRSTSECONDLAST"
    output_file.encoding.should == "BINARY"
  end
end
