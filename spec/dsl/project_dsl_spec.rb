describe "Rake::Pipeline::ProjectDSL" do
  ConcatFilter = Rake::Pipeline::SpecHelpers::Filters::ConcatFilter

  let(:project) { Rake::Pipeline::Project.new }
  let(:dsl) { Rake::Pipeline::DSL::ProjectDSL.new(project) }

  it "accepts a project in its constructor" do
    dsl.project.should == project
  end

  describe "#output" do
    it "configures the project's default_output_root" do
      dsl.output "/path/to/output"
      project.default_output_root.should == "/path/to/output"
    end
  end

  describe "#tmpdir" do
    it "sets the project's tmpdir" do
      dsl.tmpdir "/path/to/tmpdir"
      project.tmpdir.should == "/path/to/tmpdir"
    end
  end

  describe "#input" do
    it "uses Project#build_pipeline to add a new pipeline to the project" do
      project.should_receive(:build_pipeline)
      dsl.input("app") {}
    end
  end

  describe "#map" do
    it "saves the block in a hash on the project" do
      project.maps.keys.size.should == 0
      run_me = lambda { }
      dsl.map("foo", &run_me)
      dsl.project.maps["foo"].should == run_me
    end
  end
end

