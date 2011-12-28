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

  it "accepts a temporary subdirectory" do
    pipeline.tmpsubdir = "rakep"
    pipeline.tmpsubdir.should == "rakep"
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

  shared_examples_for "when working with input" do
    include Rake::Pipeline::SpecHelpers::InputHelpers

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
        files = Dir["javascripts/**/*.js"].sort
        wrappers = files.map do |file|
          Rake::Pipeline::FileWrapper.new(File.join(tmp, "app/assets"), file)
        end
        pipeline.input_files = wrappers
      end
    end
  end
end
