describe "Rake tasks" do
  before do
    @rake = Rake::Application.new
    Rake.application = @rake
  end

  describe "assets:precompile" do
    before do
      load File.expand_path("../../lib/rake-pipeline/precompile.rake", __FILE__)
      Rails = double("Rails")
      Rails.stub_chain(:application, :config, :rake_pipeline_assetfile).and_return("Assetfile")
    end

    it "creates and invokes a new Project" do
      project = double("Project")
      project.should_receive(:invoke)
      Rake::Pipeline::Project.should_receive(:new).with("Assetfile").and_return(project)
      @rake["assets:precompile"].invoke
    end
  end
end
