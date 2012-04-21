describe "Rake::Pipeline::CLI" do
  attr_reader :project, :pipeline

  before do
    @project = Rake::Pipeline::Project.new
    @project.stub(:clean)
    @project.stub(:invoke)
    @project.stub(:output_files).and_return([])
    Rake::Pipeline::Project.stub(:new).and_return(@project)
  end

  def rakep(*args)
    Rake::Pipeline::CLI.start(args)
  end

  describe "build" do
    context "with no arguments" do
      it "invokes a project" do
        project.should_receive :invoke
        rakep "build"
      end

      it "cleans up the tmpdir" do
        project.should_receive :cleanup_tmpdir
        rakep "build"
      end
    end

    context "with a --pretend argument" do
      it "doesn't invoke a project" do
        project.should_not_receive :invoke
        rakep "build", "--pretend"
      end
    end

    context "with a --clean argument" do
      it "cleans a project" do
        project.should_receive :clean
        rakep "build", "--clean"
      end

      it "invokes a project" do
        project.should_receive :invoke
        rakep "build", "--clean"
      end
    end
  end

  describe "clean" do
    context "with no arguments" do
      it "cleans a project" do
        project.should_receive :clean
        rakep "clean"
      end
    end
  end

  describe "server" do
    let(:server) { double "server" }

    before do
      require 'rake-pipeline/server'
      Rake::Pipeline::Server.stub(:new).and_return(server)
    end

    it "starts a Rake::Pipeline::Server" do
      server.should_receive :start
      rakep "server"
    end
  end

  describe "watcher" do
    let(:watcher) { double "watcher" }

    before do
      require 'rake-pipeline/watcher'
      Rake::Pipeline::Watcher.stub(:new).and_return(watcher)
    end

    it "starts a Rake::Pipeline::Watcher" do
      watcher.should_receive :start
      rakep "watch"
    end
  end
end
