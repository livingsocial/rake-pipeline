describe "GsubFilter" do
  MemoryFileWrapper ||= Rake::Pipeline::SpecHelpers::MemoryFileWrapper
  MemoryManifest ||= Rake::Pipeline::SpecHelpers::MemoryManifest

  let(:input_files) {
    [
      MemoryFileWrapper.new("/path/to/input", "ember.js", "UTF-8", "Ember.assert"),
    ]
  }

  let(:rake_application) { Rake::Application.new }

  it "generates output" do
    filter = Rake::Pipeline::GsubFilter.new "Ember.assert", "foo"
    filter.rake_application = rake_application

    filter.file_wrapper_class = MemoryFileWrapper
    filter.manifest = MemoryManifest.new
    filter.last_manifest = MemoryManifest.new

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

    filter.rake_application = rake_application
    filter.file_wrapper_class = MemoryFileWrapper
    filter.manifest = MemoryManifest.new
    filter.last_manifest = MemoryManifest.new

    filter.output_root = "/path/to/output"
    filter.input_files = input_files

    filter.output_files.should == [MemoryFileWrapper.new("/path/to/output", "ember.js", "UTF-8")]

    tasks = filter.generate_rake_tasks
    tasks.each(&:invoke)

    file = MemoryFileWrapper.files["/path/to/output/ember.js"]
    file.body.should == "foo"
  end

  it "should be able to access global match variables" do
    filter = Rake::Pipeline::GsubFilter.new /Ember\.(.+)/ do |match, word|
      word.should == "assert"
      "Ember.#{word}Strongly"
    end

    filter.rake_application = rake_application
    filter.file_wrapper_class = MemoryFileWrapper
    filter.manifest = MemoryManifest.new
    filter.last_manifest = MemoryManifest.new

    filter.output_root = "/path/to/output"
    filter.input_files = input_files

    filter.output_files.should == [MemoryFileWrapper.new("/path/to/output", "ember.js", "UTF-8")]

    tasks = filter.generate_rake_tasks
    tasks.each(&:invoke)

    file = MemoryFileWrapper.files["/path/to/output/ember.js"]
    file.body.should == "Ember.assertStrongly"
  end

  it "use the input name for output" do
    filter = Rake::Pipeline::GsubFilter.new
    filter.rake_application = rake_application
    filter.file_wrapper_class = MemoryFileWrapper
    filter.output_root = "/path/to/output"
    filter.input_files = input_files
    filter.output_files.should == [MemoryFileWrapper.new("/path/to/output", "ember.js", "UTF-8")]
  end
end
