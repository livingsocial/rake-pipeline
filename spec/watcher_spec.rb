require "rake-pipeline/watcher"

describe "Rake::Pipeline::Watcher" do
  attr_reader :project, :watcher, :listener

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
    @project.stub(:invoke_clean)

    @watcher = Rake::Pipeline::Watcher.new(@project)
    Logger.any_instance.stub(:add)

    @listener = double("listener")
    @listener.stub(:change).and_return(@listener)
    @listener.stub(:filter).and_return(@listener)
    @listener.stub(:start).and_return(@listener)
    Listen.stub(:to).and_return(@listener)
  end

  it "builds on initialization" do
    project.should_receive(:invoke_clean).once
    watcher.start
  end

  it "finds the correct paths to watch" do
    paths = watcher.watched_inputs(project)
    paths.should include([".", /^Assetfile$/])
  end

  it "starts the file watcher" do
    listener.should_receive :start
    watcher.start
  end

  it "does a clean build when a file is added." do
    listener.stub(:change).and_yield([], ['added_file'], []).and_return(listener)
    project.should_receive(:invoke_clean).at_least(2).times
    watcher.start
  end

  it "does a clean build when a file is removed." do
    listener.stub(:change).and_yield([], [], ['removed_file']).and_return(listener)
    project.should_receive(:invoke_clean).at_least(2).times
    watcher.start
  end

  it "does a clean build when the Assetfile is modified." do
    listener.stub(:change).and_yield(['Assetfile'], [], []).and_return(listener)
    project.should_receive(:invoke_clean).at_least(2).times
    watcher.start
  end

  it "does a regular build when a non-Assetfile is modified." do
    listener.stub(:change).and_yield(['modified_file'], [], []).and_return(listener)
    project.should_receive(:invoke_clean).once
    project.should_receive(:invoke).at_least(1).times
    watcher.start
  end

  it "stops the listeners when it is stopped." do
    watcher.start
    listener.should_receive(:stop).at_least(1).times
    watcher.stop
  end
end
