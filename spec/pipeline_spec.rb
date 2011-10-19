describe "Rake::Pipeline" do
  let(:pipeline) { Rake::Pipeline.new }

  class ConcatFilter < Rake::Pipeline::Filter
    def generate_output(inputs, output)
      inputs.each do |input|
        output.write input.read
      end
    end
  end

  class StripAssertsFilter < Rake::Pipeline::Filter
    def generate_output(inputs, output)
      inputs.each do |input|
        output.write input.read.gsub(%r{^\s*assert\(.*\)\s*;?\s*$}m, '')
      end
    end
  end

  it "accepts a input root" do
    pipeline.input_root = "app/assets"
    pipeline.input_root.should == "app/assets"
  end

  it "raises an exception on #relative_input_files if input_files are not provided" do
    pipeline.input_root = "app/assets"
    lambda { pipeline.input_files }.should raise_error(Rake::Pipeline::Error)
  end

  it "raises an exception on #relative_input_files if input_root is not provided" do
    pipeline.input_glob = "app/assets/javascripts/**/*.js"
    lambda { pipeline.input_files }.should raise_error(Rake::Pipeline::Error)
  end

  it "accepts a temporary directory" do
    pipeline.tmpdir = "tmp"
    pipeline.tmpdir.should == "tmp"
  end

  it "accepts an output directory" do
    pipeline.output_root = "public"
    pipeline.output_root.should == "public"
  end

  it "accepts a rake application" do
    app = Rake::Application.new
    pipeline.rake_application = app
    pipeline.rake_application.should == app
  end

  it "defaults the rake application to Rake.application" do
    pipeline.rake_application.should == Rake.application
  end

  it "can have filters added to it" do
    filter = ConcatFilter.new
    pipeline.add_filter filter
  end

  describe "when working with input" do
    def input_file(path, root=File.join(tmp, "app/assets"))
      Rake::Pipeline::FileWrapper.new root, path
    end

    let(:files) do
      %w(javascripts/jquery.js javascripts/sproutcore.js).map do |filename|
        input_file(filename)
      end
    end

    before do
      Rake.application = Rake::Application.new

      files.each do |file|
        mkdir_p File.dirname(file.fullpath)

        File.open(file.fullpath, "w") do |file|
          file.write "// This is #{file.path}\n"
        end
      end

      pipeline.input_root = "app/assets"
      pipeline.input_glob = "javascripts/**/*.js"
      pipeline.output_root = "public"
    end

    it "accepts a list of relative input files" do
      pipeline.input_files.should == files
    end

    it "configures the filters with outputs and inputs with #rake_tasks" do
      concat = ConcatFilter.new
      concat.output_name = proc { |input| "javascripts/application.js" }

      strip_asserts = StripAssertsFilter.new
      strip_asserts.output_name = proc { |input| input }

      pipeline.add_filters concat, strip_asserts
      pipeline.rake_tasks

      concat.input_files.should == pipeline.input_files
      strip_asserts.input_files.each { |file| file.root.should == concat.output_root }

      strip_asserts.input_files.should == [input_file("javascripts/application.js", concat.output_root)]
      strip_asserts.output_root.should == File.expand_path(pipeline.output_root)
    end

    describe "generating rake tasks" do
      tasks = nil

      before do
        concat = ConcatFilter.new
        concat.output_name = proc { |input| "javascripts/application.js" }
        pipeline.add_filter concat
      end

      it "generates rake tasks in Rake.application" do
        tasks = pipeline.rake_tasks

        tasks.size.should == 1
        task = tasks[0]
        task.name.should == File.join(tmp, pipeline.output_root, "javascripts/application.js")

        deps = task.prerequisites
        deps.size.should == 2
        deps[0].should == File.join(tmp, pipeline.input_root, "javascripts/jquery.js")
        deps[1].should == File.join(tmp, pipeline.input_root, "javascripts/sproutcore.js")

        Rake.application.tasks.size.should == 3
      end

      it "generates rake tasks is an alternate Rake::Application" do
        app = Rake::Application.new
        pipeline.rake_application = app
        tasks = pipeline.rake_tasks

        Rake.application.tasks.size.should == 0
      end
    end
  end
end
