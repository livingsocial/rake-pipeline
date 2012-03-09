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

  it "can access its glob" do
    @matcher.glob = "*.js"
    @matcher.glob.should == "*.js"
  end

  it "knows about its containing pipeline" do
    pipeline = Rake::Pipeline.new
    pipeline.add_filter @matcher
    @matcher.pipeline.should == pipeline
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

  def should_match_glob(glob, files)
    @matcher.glob = glob
    @matcher.output_root = "tmp1"

    concat = Rake::Pipeline::ConcatFilter.new
    concat.output_name_generator = proc { |input| input }
    @matcher.add_filter concat

    @matcher.setup

    @matcher.output_files.should == files
  end

  it "understands */* style globs" do
    @matcher.input_files << file_wrapper("javascripts/backbone.js")
    @matcher.input_files << file_wrapper("something/javascripts/backbone.js")

    should_match_glob "*/*.js", [
      file_wrapper("javascripts/backbone.js", :encoding => "BINARY", :root => File.join(tmp, "tmp1")),
      file_wrapper("jquery.js"),
      file_wrapper("sproutcore.js"),
      file_wrapper("sproutcore.css"),
      file_wrapper("something/javascripts/backbone.js")
    ]

    should_match_glob "proutcore*.js", [
      file_wrapper("jquery.js"),
      file_wrapper("sproutcore.js"),
      file_wrapper("sproutcore.css"),
      file_wrapper("javascripts/backbone.js"),
      file_wrapper("something/javascripts/backbone.js")
    ]
  end

  it "understands **/* style globs" do
    @matcher.input_files << file_wrapper("javascripts/backbone.js")

    output_root = File.join(tmp, "tmp1")

    should_match_glob "**/*.js", [
      file_wrapper("jquery.js", :encoding => "BINARY", :root => output_root),
      file_wrapper("sproutcore.js", :encoding => "BINARY", :root => output_root),
      file_wrapper("javascripts/backbone.js", :encoding => "BINARY", :root => output_root),
      file_wrapper("sproutcore.css")
    ]
  end

  it "understands {foo,bar}/* style globs" do
    @matcher.input_files << file_wrapper("javascripts/backbone.js")

    output_root = File.join(tmp, "tmp1")

    should_match_glob "{jquery,sproutcore}.js", [
      file_wrapper("jquery.js", :encoding => "BINARY", :root => output_root),
      file_wrapper("sproutcore.js", :encoding => "BINARY", :root => output_root),
      file_wrapper("sproutcore.css"),
      file_wrapper("javascripts/backbone.js")
    ]
  end

  it "accepts Regexp as glob" do
    regexp = /application\.erb/
    @matcher.glob = regexp

    @matcher.glob.should == regexp
  end

  it "underestands regexp globs" do
    regexp = /^*(?<!\.coffee)\.js$/i

    @matcher.input_files << file_wrapper("application.coffee.js")
    @matcher.input_files << file_wrapper("application.engine.js")

    output_root = File.join(tmp, "tmp1")

    should_match_glob regexp, [
      file_wrapper("jquery.js", :encoding => "BINARY", :root => output_root),
      file_wrapper("sproutcore.js", :encoding => "BINARY", :root => output_root),
      file_wrapper("application.engine.js", :encoding => "BINARY", :root => output_root),
      file_wrapper("sproutcore.css"),
      file_wrapper("application.coffee.js")
    ]
  end
end
