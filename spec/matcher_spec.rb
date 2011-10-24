describe "a matcher" do
  sep = File::SEPARATOR

  before do
    @matcher = Rake::Pipeline::Matcher.new
    @files = %w(jquery.js sproutcore.js sproutcore.css).map do |file|
      file_wrapper(file)
    end

    @matcher.input_files = @files
  end

  def file_wrapper(file, options={})
    root = options[:root] || tmp
    encoding = options[:encoding] || "UTF-8"
    Rake::Pipeline::FileWrapper.new(root, file, encoding)
  end

  it "accepts input files" do
    @matcher.input_files.should == @files
  end

  describe "accepting glob patterns" do
    it "converts **" do
      @matcher.glob = "**/application.js"
      @matcher.pattern.should == %r{.*/application\.js$}i
    end

    it "converts *" do
      @matcher.glob = "*.js"
      @matcher.pattern.should == /[^#{sep}]*\.js$/i
    end

    it "converts {}" do
      @matcher.glob = "*.{js,css}"
      @matcher.pattern.should == /[^#{sep}]*\.(js|css)$/i
    end
  end

  it "only processes files matching the matcher" do
    @matcher.glob = "*.js"
    @matcher.output_root = "tmp1"

    concat = Rake::Pipeline::ConcatFilter.new
    concat.output_name_generator = proc { |input| "app.js" }
    @matcher.add_filter concat

    @matcher.setup

    concat.input_files.should == [
      file_wrapper("jquery.js", :encoding => "BINARY"),
      file_wrapper("sproutcore.js", :encoding => "BINARY")
    ]

    @matcher.output_files.should == [
      file_wrapper("app.js", :root => File.join(tmp, "tmp1")),
      file_wrapper("sproutcore.css")
    ]
  end
end
