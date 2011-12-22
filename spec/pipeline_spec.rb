describe "Rake::Pipeline" do
  ConcatFilter = Rake::Pipeline::SpecHelpers::Filters::ConcatFilter
  StripAssertsFilter = Rake::Pipeline::SpecHelpers::Filters::StripAssertsFilter

  let(:pipeline) { Rake::Pipeline.new }

  it "accepts a input root" do
    pipeline.add_input "app/assets"
    pipeline.inputs["app/assets"].should == '**/*'
  end

  it "raises an exception on #relative_input_files if input_files are not provided" do
    lambda { pipeline.input_files }.should raise_error(Rake::Pipeline::Error)
  end

  it "accepts a temporary directory" do
    pipeline.tmpdir = "tmp"
    pipeline.tmpdir.should == File.expand_path("tmp")
  end

  it "accepts an output directory" do
    pipeline.output_root = "public"
    pipeline.output_root.should == File.expand_path("public")
  end

  it "accepts a rake application" do
    app = Rake::Application.new
    pipeline.rake_application = app
    pipeline.rake_application.should == app
  end

  it "defaults the rake application to Rake.application" do
    pipeline.rake_application.should == Rake.application
  end

  describe "adding filters" do
    let(:filter) { ConcatFilter.new }

    it "can have filters added to it" do
      pipeline.add_filter filter
    end

    it "sets an added filter's rake_application" do
      app = Rake::Application.new
      pipeline.rake_application = app
      pipeline.add_filter filter
      filter.rake_application.should == app
    end

    it "sets an added filter's pipeline" do
      pipeline.add_filter filter
      filter.pipeline.should == pipeline
    end
  end

  module InputHelpers
    def input_file(path, root=File.join(tmp, "app/assets"))
      Rake::Pipeline::FileWrapper.new root, path
    end

    def output_file(path, root=File.join(tmp, "public"))
      input_file(path, root)
    end

    def create_files(files)
      Array(files).each do |file|
        mkdir_p File.dirname(file.fullpath)

        File.open(file.fullpath, "w") do |file|
          file.write "// This is #{file.path}\n"
        end
      end
    end
  end

  shared_examples_for "when working with input" do
    include InputHelpers

    let(:files) do
      %w(javascripts/jquery.js javascripts/sproutcore.js).map do |filename|
        input_file(filename)
      end
    end

    def setup_roots
      pipeline.add_input "app/assets"
    end

    before do
      Rake.application = Rake::Application.new
      create_files(files)
      setup_roots
      setup_input(pipeline)
      pipeline.output_root = "public"
    end

    it "accepts a list of relative input files" do
      pipeline.input_files.should == files
    end

    it "configures the filters with outputs and inputs with #rake_tasks" do
      concat = ConcatFilter.new
      concat.output_name_generator = proc { |input| "javascripts/application.js" }

      strip_asserts = StripAssertsFilter.new
      strip_asserts.output_name_generator = proc { |input| input }

      pipeline.add_filters concat, strip_asserts
      pipeline.setup

      concat.input_files.should == pipeline.input_files
      strip_asserts.input_files.each { |file| file.root.should == concat.output_root }

      strip_asserts.input_files.should == [input_file("javascripts/application.js", concat.output_root)]
      strip_asserts.output_root.should == File.expand_path(pipeline.output_root)
    end

    describe "generating rake tasks" do
      tasks = nil

      before do
        concat = ConcatFilter.new
        concat.output_name_generator = proc { |input| "javascripts/application.js" }
        pipeline.add_filter concat
      end

      it "generates rake tasks in Rake.application" do
        pipeline.setup
        tasks = pipeline.rake_tasks

        tasks.size.should == 1
        task = tasks[0]
        task.name.should == File.join(pipeline.output_root, "javascripts/application.js")

        deps = task.prerequisites
        deps.size.should == 2

        root = File.expand_path(pipeline.inputs.keys.first)

        deps[0].should == File.join(root, "javascripts/jquery.js")
        deps[1].should == File.join(root, "javascripts/sproutcore.js")

        Rake.application.tasks.size.should == 3
      end

      it "generates rake tasks is an alternate Rake::Application" do
        app = Rake::Application.new
        pipeline.rake_application = app
        pipeline.setup
        tasks = pipeline.rake_tasks

        Rake.application.tasks.size.should == 0
      end
    end
  end

  describe "when using multiple input roots" do
    it_behaves_like "when working with input"

    def setup_roots
      pipeline.add_input File.join(tmp, 'tmp1', "app/assets"), '**/*.js'
      pipeline.add_input File.join(tmp, 'tmp2', "app/assets"), '**/*.css'
    end

    def setup_input(pipeline)
    end

    let(:files) do
      f = []

      %w(javascripts/jquery.js javascripts/sproutcore.js).map do |filename|
        f << input_file(filename, File.join(tmp, 'tmp1', "app/assets"))
      end

      %w(stylesheets/jquery.css stylesheets/sproutcore.css).map do |filename|
        f << input_file(filename, File.join(tmp, 'tmp2', "app/assets"))
      end

      f
    end
  end

  describe "using an array for input files" do
    it_behaves_like "when working with input"

    def setup_input(pipeline)
      Dir.chdir("app/assets") do
        files = Dir["javascripts/**/*.js"]
        wrappers = files.map do |file|
          Rake::Pipeline::FileWrapper.new(File.join(tmp, "app/assets"), file)
        end
        pipeline.input_files = wrappers
      end
    end
  end

  describe "clobbering a pipeline" do
    include InputHelpers

    let(:input_files) do
      %w(jquery.js ember.js).map { |f| input_file(f) }
    end

    let(:output_files) do
      input_files.map { |f| output_file(f.path) }
    end

    before do
      Rake.application = Rake::Application.new
      create_files(input_files)
      pipeline.add_input "app/assets"
      pipeline.output_root = "public"
      pipeline.tmpdir = "temporary"
      pipeline.add_filter ConcatFilter.new
      # Add two filters so we know we need a tmp dir
      pipeline.add_filter ConcatFilter.new
    end

    it "removes the pipeline's output files" do
      pipeline.invoke
      output_files.each { |f| f.exists?.should be_true }
      pipeline.clobber
      output_files.each { |f| f.exists?.should be_false }
    end

    it "cleans out the pipeline's tmp dir" do
      pipeline.invoke
      Dir["./temporary/rake-pipeline-tmp*"].should_not be_empty
      pipeline.clobber
      Dir["./temporary/rake-pipeline-tmp*"].should be_empty
    end
  end

  describe "A pipeline with an Assetfile" do
    include InputHelpers

    let(:input_files) do
      %w(jquery.js ember.js).map { |f| input_file(f) }
    end

    let(:output_files) do
      input_files.map { |f| output_file(f.path) }
    end

    let(:assetfile_path) { File.join(tmp, "Assetfile") }

    let(:pipeline) { Rake::Pipeline.from_assetfile("Assetfile") }

    def assetfile_digest
      (Digest::SHA1.new << File.read(assetfile_path)).to_s
    end

    before do
      create_files input_files
      File.open(File.join(tmp, "Assetfile"), "w") { |file| file.write(<<-HERE) }
        require "#{tmp}/../support/spec_helpers/filters"
        tmpdir "temporary"
        input "app/assets"
        filter Rake::Pipeline::ConcatFilter
        filter Rake::Pipeline::ConcatFilter
        output "public"
      HERE
    end

    it "is created from the configuration in the Assetfile" do
      pipeline.tmpdir.should == File.join(tmp, "temporary")
      pipeline.output_root.should == File.join(tmp, "public")
      pipeline.inputs.should include("app/assets" => "**/*")
    end

    it "has an assetfile_path" do
      pipeline.assetfile_path.should == assetfile_path
    end

    it "has an assetfile_digest" do
      pipeline.assetfile_digest.should == assetfile_digest
    end

    it "writes temp files to a subdirectory of the tmp dir named after the assetfile_digest" do
      pipeline.invoke
      digest_dir = File.join(tmp, "temporary", "rake-pipeline-#{assetfile_digest}")
      File.directory?(digest_dir).should be_true
    end

    it "is outdated if the Assetfile contents change" do
      pipeline.outdated?.should be_false

      original_assetfile_digest = assetfile_digest
      File.open(assetfile_path, 'a') do |file|
        file.write("filter Rake::Pipeline::ConcatFilter\n")
      end

      original_assetfile_digest.should_not == assetfile_digest
      pipeline.outdated?.should be_true
    end

    it "clears out old temp dirs when invoked" do
      old_dir = File.join(tmp, "temporary", "rake-pipeline-2903i49839492384")
      mkdir_p old_dir
      pipeline.invoke
      File.exist?(old_dir).should be_false
    end
  end
end
