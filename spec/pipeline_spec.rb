describe "Rake::Pipeline" do
  let(:pipeline) { Rake::Pipeline.new }

  it "accepts a root" do
    pipeline.root = "app/assets"
    pipeline.root.should == "app/assets"
  end

  it "accepts a glob" do
    pipeline.glob = "javascripts/**/*.js"
    pipeline.glob.should == "javascripts/**/*.js"
  end
end
