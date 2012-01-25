describe "Rake::Pipeline::Project" do
  include Rake::Pipeline::SpecHelpers::InputHelpers

  ASSETFILE_SOURCE = <<-HERE.gsub(/^ {4}/, '')
    require "#{tmp}/../support/spec_helpers/filters"
    input "app/assets"
    tmpdir "tmp"

    match "*.js" do
      filter(Rake::Pipeline::ConcatFilter) { "javascripts/application.js" }
      filter(Rake::Pipeline::SpecHelpers::Filters::StripAssertsFilter)
    end

    output "public"
  HERE

  MODIFIED_ASSETFILE_SOURCE = <<-HERE.gsub(/^ {4}/, '')
    require "#{tmp}/../support/spec_helpers/filters"
    input "app/assets"
    tmpdir "tmp"

    match "*.js" do
      filter(Rake::Pipeline::ConcatFilter) { "javascripts/app.js" }
      filter(Rake::Pipeline::SpecHelpers::Filters::StripAssertsFilter)
    end

    output "public"
  HERE

  let(:assetfile_path) { File.join(tmp, "Assetfile") }

  def assetfile_digest
    (Digest::SHA1.new << File.read(assetfile_path)).to_s
  end

  let(:input_files) do
    %w(jquery.js ember.js).map { |f| input_file(f) }
  end

  let(:output_files) do
    [output_file("javascripts/application.js")]
  end

  let(:project) { Rake::Pipeline::Project.new(assetfile_path) }

  before do
    File.open(assetfile_path, 'w') { |file| file.write(ASSETFILE_SOURCE) }
    create_files(input_files)
  end

  it "has an assetfile_path" do
    project.assetfile_path.should == assetfile_path
  end

  it "has an assetfile_digest" do
    project.assetfile_digest.should == assetfile_digest
  end

  describe "constructor" do
    it "creates a pipeline from an Assetfile given an Assetfile path" do
      project = Rake::Pipeline::Project.new(assetfile_path)
      pipeline = project.pipeline
      pipeline.inputs.should == { "app/assets" => "**/*" }
      pipeline.output_root.should == File.join(tmp, "public")
    end

    it "wraps an existing pipeline" do
      pipeline = Rake::Pipeline.class_eval("build do\n#{File.read(assetfile_path)}\nend", assetfile_path, 1)
      project = Rake::Pipeline::Project.new(pipeline)
      project.pipeline.should == pipeline
    end
  end

  describe "#invoke" do
    it "creates output files from a pipeline" do
      output_files.each { |file| file.should_not exist }
      project.invoke
      output_files.each { |file| file.should exist }
    end

    it "writes temp files to a subdirectory of the tmp dir named after the assetfile digest" do
      project.invoke
      digest_dir = File.join(tmp, "tmp", "rake-pipeline-#{assetfile_digest}")
      File.exist?(digest_dir).should be_true
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
        original_pipeline = project.pipeline
        original_assetfile_digest = assetfile_digest

        modify_assetfile
        project.invoke_clean
        assetfile_digest.should_not == original_assetfile_digest
        project.pipeline.should_not == original_pipeline
      end
    end
  end

  describe "#cleanup_tmpdir" do
    let(:old_dir) { File.join(tmp, "tmp", "rake-pipeline-ad7a83894789") }

    before do
      mkdir_p old_dir
    end

    it "cleans old rake-pipeline-* dirs out of the pipeline's tmp dir" do
      File.exist?(old_dir).should be_true
      project.cleanup_tmpdir
      File.exist?(old_dir).should be_false
    end

    it "leaves the current assetfile-digest tmp dir alone" do
      project.invoke
      File.exist?(File.join(tmp, "tmp", project.digested_tmpdir)).should be_true
      project.cleanup_tmpdir
      File.exist?(File.join(tmp, "tmp", project.digested_tmpdir)).should be_true
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
  end
end
