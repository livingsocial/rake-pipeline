describe "Rake::Pipeline::Runner" do
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

  let(:runner) { Rake::Pipeline::Runner.new(assetfile_path) }

  before do
    File.open(assetfile_path, 'w') { |file| file.write(ASSETFILE_SOURCE) }
    create_files(input_files)
  end

  it "has an assetfile_path" do
    runner.assetfile_path.should == assetfile_path
  end

  it "has an assetfile_digest" do
    runner.assetfile_digest.should == assetfile_digest
  end

  describe ".from_assetfile" do
    it "creates a pipeline from an Assetfile given an Assetfile path" do
      runner = Rake::Pipeline::Runner.from_assetfile(assetfile_path)
      pipeline = runner.pipeline
      pipeline.inputs.should == { "app/assets" => "**/*" }
      pipeline.output_root.should == File.join(tmp, "public")
    end

    it "wraps an existing pipeline" do
      pipeline = Rake::Pipeline.class_eval("build do\n#{File.read(assetfile_path)}\nend", assetfile_path, 1)
      runner = Rake::Pipeline::Runner.from_assetfile(pipeline)
      runner.pipeline.should == pipeline
    end
  end

  describe "invoking a runner" do
    it "writes temp files to a subdirectory of the tmp dir named after the assetfile digest" do
      runner.invoke_clean
      digest_dir = File.join(tmp, "tmp", "rake-pipeline-#{assetfile_digest}")
      File.exist?(digest_dir).should be_true
    end

    context "if the Assetfile contents have changed" do
      def modify_assetfile
        File.open(assetfile_path, 'w') do |file|
          file.write(MODIFIED_ASSETFILE_SOURCE)
        end
      end

      it "rebuilds its pipeline" do
        runner.invoke_clean
        original_pipeline = runner.pipeline
        original_assetfile_digest = assetfile_digest

        modify_assetfile
        runner.invoke_clean
        assetfile_digest.should_not == original_assetfile_digest
        runner.pipeline.should_not == original_pipeline
      end

      it "removes old temp dirs" do
        runner.invoke_clean
        original_tmpdir = File.join(tmp, "tmp", runner.digested_tmpdir)
        File.exist?(original_tmpdir).should be_true

        modify_assetfile
        runner.invoke_clean
        File.exist?(original_tmpdir).should be_false
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
      runner.cleanup_tmpdir
      File.exist?(old_dir).should be_false
    end

    it "leaves the current assetfile-digest tmp dir alone" do
      runner.build
      File.exist?(File.join(tmp, "tmp", runner.digested_tmpdir)).should be_true
      runner.cleanup_tmpdir
      File.exist?(File.join(tmp, "tmp", runner.digested_tmpdir)).should be_true
    end
  end

  describe "the build task" do
    it "creates output files from a pipeline" do
      runner.pipeline.output_files.each { |file| file.should_not exist }
      runner.invoke(:build, [])
      runner.pipeline.output_files.each { |file| file.should exist }
    end

    context "if the :pretend option is set" do
      it "doesn't create output files" do
        runner.pipeline.output_files.each { |file| file.should_not exist }
        runner.invoke(:build, [], :pretend => true)
        runner.pipeline.output_files.each { |file| file.should_not exist }
      end
    end
  end

  describe "the clean task" do
    def rakep_tmpdirs
      Dir["#{tmp}/tmp/rake-pipeline-*"]
    end

    it "cleans all rake-pipeline-* dirs out of the pipeline's tmp dir" do
      runner.invoke(:build, [])
      rakep_tmpdirs.should_not be_empty
      runner.invoke(:clean, [])
      rakep_tmpdirs.should be_empty
    end

    it "removes the pipeline's output files" do
      runner.invoke(:build, [])
      output_files.each { |f| f.should exist }
      runner.invoke(:clean, [])
      output_files.each { |f| f.should_not exist }
    end

    context "if the :pretend option is set" do
      it "doesn't remove any files" do
        runner.invoke(:build, [])
        output_files.each { |f| f.should exist }
        rakep_tmpdirs.should_not be_empty

        runner.invoke(:clean, [], :pretend => true)
        output_files.each { |f| f.should exist }
        rakep_tmpdirs.should_not be_empty
      end
    end
  end
end
