describe "Rake::Pipeline::Project" do
  include Rake::Pipeline::SpecHelpers::InputHelpers

  ASSETFILE_SOURCE = <<-HERE.gsub(/^ {4}/, '')
    require "#{tmp}/../support/spec_helpers/filters"
    tmpdir "tmp"
    output "public"

    input "app/assets" do
      match "*.js" do
        concat "javascripts/application.js"
        filter Rake::Pipeline::SpecHelpers::Filters::StripAssertsFilter
      end
    end
  HERE

  MODIFIED_ASSETFILE_SOURCE = <<-HERE.gsub(/^ {4}/, '')
    require "#{tmp}/../support/spec_helpers/filters"
    tmpdir "tmp"
    output "public"

    input "app/assets" do
      match "*.js" do
        concat "javascripts/app.js"
        filter Rake::Pipeline::SpecHelpers::Filters::StripAssertsFilter
      end
    end
  HERE

  BAD_ASSETFILE_SOURCE = <<-HERE.gsub(/^ {4}/, '')
    require "#{tmp}/../support/spec_helpers/filters"
    tmpdir "tmp"
    output "public"

    input "app/assets" do
      method_not_in_dsl_on_line_6
    end
  HERE

  let(:assetfile_path) { File.join(tmp, "Assetfile") }

  def assetfile_digest
    (Digest::SHA1.new << File.read(assetfile_path)).to_s
  end

  let(:unmatched_file) { input_file("junk.txt") }

  let(:input_files) do
    [input_file("jquery.js"), input_file("ember.js"), unmatched_file]
  end

  let(:output_files) do
    [output_file("javascripts/application.js")]
  end

  let(:old_tmpdir) do
    File.join(tmp, "tmp", "rake-pipeline-ad7a83894789")
  end

  let(:digested_tmpdir) do
    File.join(tmp, "tmp", "rake-pipeline-#{assetfile_digest}")
  end

  attr_reader :project

  before do
    File.open(assetfile_path, 'w') { |file| file.write(ASSETFILE_SOURCE) }
    create_files(input_files)
    @project = Rake::Pipeline::Project.new(assetfile_path)
    mkdir_p(old_tmpdir)
  end

  it "has an assetfile_path" do
    project.assetfile_path.should == assetfile_path
  end

  it "has an assetfile_digest" do
    project.assetfile_digest.should == assetfile_digest
  end

  it "has a pipeline" do
    project.should have(1).pipelines
  end

  describe "constructor" do
    it "creates pipelines from an Assetfile given an Assetfile path" do
      project = Rake::Pipeline::Project.new(assetfile_path)
      project.maps.should == {}
      pipeline = project.pipelines.last
      pipeline.inputs.should == { "app/assets" => "**/*" }
      pipeline.output_root.should == File.join(tmp, "public")
    end

    it "wraps an existing pipeline" do
      pipeline = Rake::Pipeline::Project.class_eval("build do\n#{File.read(assetfile_path)}\nend", assetfile_path, 1)
      project = Rake::Pipeline::Project.new(pipeline)
      project.pipelines.last.should == pipeline
    end
  end

  describe "#invoke" do
    it "creates output files" do
      output_files.each { |file| file.should_not exist }
      project.invoke
      output_files.each { |file| file.should exist }
    end

    it "writes temp files to a subdirectory of the tmp dir named after the assetfile digest" do
      project.invoke
      File.exist?(digested_tmpdir).should be_true
    end
  end

  describe "invalid Assetfile" do
    before do
      File.open(assetfile_path, 'w') { |file| file.write(BAD_ASSETFILE_SOURCE) }
    end

    it "should raise error with assetfile path on correct line number" do
      lambda {
        Rake::Pipeline::Project.new(assetfile_path)
      }.should raise_error {|error| error.backtrace[0].should match(/Assetfile:6/) }
    end
  end

  describe "#invoke_clean" do
    context "if the Assetfile contents have changed" do
      def modify_assetfile
        File.open(assetfile_path, 'w') do |file|
          file.write(MODIFIED_ASSETFILE_SOURCE)
        end
      end

      it "rebuilds its pipeline" do
        project.invoke_clean
        original_pipeline = project.pipelines.last
        original_assetfile_digest = assetfile_digest

        modify_assetfile
        project.invoke_clean
        assetfile_digest.should_not == original_assetfile_digest
        project.pipelines.last.should_not == original_pipeline
      end
    end
  end

  describe "#cleanup_tmpdir" do
    it "cleans old rake-pipeline-* dirs out of the pipeline's tmp dir" do
      File.exist?(old_tmpdir).should be_true
      project.cleanup_tmpdir
      File.exist?(old_tmpdir).should be_false
    end

    it "leaves the current assetfile-digest tmp dir alone" do
      project.invoke
      File.exist?(digested_tmpdir).should be_true
      project.cleanup_tmpdir
      File.exist?(digested_tmpdir).should be_true
    end
  end

  describe "#clean" do
    def rakep_tmpdirs
      Dir["#{tmp}/tmp/rake-pipeline-*"]
    end

    it "cleans all rake-pipeline-* dirs out of the pipeline's tmp dir" do
      project.invoke
      rakep_tmpdirs.should_not be_empty
      project.clean
      rakep_tmpdirs.should be_empty
    end

    it "removes the pipeline's output files" do
      project.invoke
      output_files.each { |f| f.should exist }
      project.clean
      output_files.each { |f| f.should_not exist }
    end

    it "leaves the pipeline's unmatched input files alone" do
      project.invoke
      project.clean
      unmatched_file.should exist
    end
  end

  describe ".add_to_digest" do
    after do
      Rake::Pipeline::Project.digest_additions = []
    end

    it "appends a string to the generated tmp dir name" do
      Rake::Pipeline::Project.add_to_digest("octopus")

      File.basename(project.digested_tmpdir).should ==
        "rake-pipeline-#{assetfile_digest}-octopus"
    end

    it "can be called multiple times" do
      Rake::Pipeline::Project.add_to_digest("a")
      Rake::Pipeline::Project.add_to_digest("b")

      File.basename(project.digested_tmpdir).should ==
        "rake-pipeline-#{assetfile_digest}-a-b"
    end
  end

  describe "#build_pipeline" do
    let(:inputs) { {"foo" => "**/*"} }

    it "returns a pipeline" do
      pipeline = project.build_pipeline(inputs) {}
      pipeline.should be_kind_of(Rake::Pipeline)
    end

    it "adds the pipeline to the list of pipelines" do
      pipeline = project.build_pipeline(inputs) {}
      project.pipelines.last.should == pipeline
    end

    it "configures the pipeline with the pipeline DSL" do
      pipeline = project.build_pipeline(inputs) do
        output "bar"
      end

      pipeline.output_root.should == File.expand_path("bar")
    end

    it "sets the pipeline's tmpdir to a digest tmpdir" do
      pipeline = project.build_pipeline(inputs) {}
      pipeline.tmpdir.should == project.digested_tmpdir
    end

    it "sets the pipeline's output_root to the default_output_root" do
      pipeline = project.build_pipeline(inputs) {}
      pipeline.output_root.should == project.default_output_root
    end

    it "creates a pipeline with a given set of inputs" do
      pipeline = project.build_pipeline(inputs) {}
      pipeline.inputs.should == inputs
    end

    it "can be called with a single path input" do
      pipeline = project.build_pipeline("/path") {}
      pipeline.inputs.should == {"/path" => "**/*"}
    end

    it "can be called with a path and a glob" do
      pipeline = project.build_pipeline("/path", "*.js") {}
      pipeline.inputs.should == {"/path" => "*.js"}
    end

    it "can be called with an array of paths" do
      pipeline = project.build_pipeline(["path1", "path2"]) {}
      pipeline.inputs.should have_key("path1")
      pipeline.inputs.should have_key("path2")
    end

    it "can be called with a hash of path => glob pairs" do
      pipeline = project.build_pipeline({"/path" => "*.css"}) {}
      pipeline.inputs.should == {"/path" => "*.css"}
    end
  end

  describe "#obsolete_tmpdirs" do
    it "includes tmp directories that don't match the current digest" do
      project.obsolete_tmpdirs.should include(old_tmpdir)
    end
  end

  describe "#files_to_clean" do
    it "includes a project's output files" do
      output_files.each do |file|
        project.files_to_clean.should include(file.fullpath)
      end
    end

    it "includes a project's temporary directory" do
      project.files_to_clean.should include(digested_tmpdir)
    end

    it "includes any old digest tmp dirs" do
      project.files_to_clean.should include(old_tmpdir)
    end
  end
end
