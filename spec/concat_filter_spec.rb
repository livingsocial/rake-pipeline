describe "ConcatFilter" do
  class MemoryFileWrapper < Struct.new(:root, :path, :encoding, :body)
    @@files = {}

    def self.files
      @@files
    end

    def with_encoding(new_encoding)
      self.class.new(root, path, new_encoding, body)
    end

    def fullpath
      File.join(root, path)
    end

    def create
      @@files[fullpath] = self
      self.body = ""
      yield
    end

    alias read body

    def write(contents)
      self.body << contents
    end
  end

  it "generates output" do
    files = [
      MemoryFileWrapper.new("/path/to/input", "javascripts/jquery.js", "UTF-8", "jQuery = {};"),
      MemoryFileWrapper.new("/path/to/input", "javascripts/sproutcore.js", "UTF-8", "SC = {};")
    ]

    app = Rake::Application.new

    filter = ::Rake::Pipeline::ConcatFilter.new(MemoryFileWrapper)
    filter.input_files = files
    filter.output_root = "/path/to/output"
    filter.output_name_generator = proc { "application.js" }
    filter.rake_application = app

    filter.output_files.should == [MemoryFileWrapper.new("/path/to/output", "application.js", "BINARY")]

    tasks = filter.generate_rake_tasks
    tasks.each(&:invoke)

    file = MemoryFileWrapper.files["/path/to/output/application.js"]
    file.body.should == "jQuery = {};SC = {};"
    file.encoding.should == "BINARY"
  end
end
