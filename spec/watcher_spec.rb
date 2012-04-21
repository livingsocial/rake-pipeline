require "rake-pipeline/watcher"

describe "Rake::Pipeline::Watcher" do
  attr_reader :project, :watcher, :monitor

  assetfile_source = <<-HERE.gsub(/^ {4}/, '')
    output "public"
    input "#{tmp}", "app/**/*" do
      concat { |input| input.sub(%r|^app/|, '') }
    end
  HERE

  let(:assetfile_path){ File.join(tmp, "Assetfile") }

  before do
    File.open(assetfile_path, "w") { |file| file.write(assetfile_source) }

    @project = Rake::Pipeline::Project.new(assetfile_path)
    @project.stub(:invoke)

    @watcher = Rake::Pipeline::Watcher.new(@project)
    @watcher.stub(:puts)

    @monitor = double("monitor")
    @monitor.stub(:path)
    @monitor.stub(:run)
    FSSM::Monitor.stub(:new).and_return(@monitor)
  end

  it "builds on initialization" do
    project.should_receive :invoke
    watcher.start
  end

  it "finds the correct paths to watch" do
    paths = watcher.watched_inputs(project)
    paths['.'].should == ["Assetfile"]
    paths[tmp].should == ["app/**/*"]
  end

  it "starts the file watcher" do
    monitor.should_receive :run
    watcher.start
  end
end
