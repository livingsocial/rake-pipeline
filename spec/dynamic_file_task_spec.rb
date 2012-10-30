require 'spec_helper'

describe Rake::Pipeline::DynamicFileTask do
  let(:invoked_tasks) { [] }

  def define_task(deps, klass=Rake::Pipeline::DynamicFileTask, &task_proc)
    task_proc ||= proc do |task|
      touch(task.name)
      invoked_tasks << task
    end

    task = klass.define_task(deps, &task_proc)

    if klass == Rake::Pipeline::DynamicFileTask 
      task.manifest = Rake::Pipeline::Manifest.new
    end

    task
  end

  let(:task) { define_task('output') }

  before do
    # Make sure date conversions happen in UTC, not local time
    ENV['TZ'] = 'UTC'
  end

  after do
    # Clean out all defined tasks after each test runs
    Rake.application = Rake::Application.new
  end

  describe "#dynamic" do
    it "saves a block that can be called later with #invoke_dynamic_block" do
      block = proc {}
      task.dynamic(&block)
      block.should_receive(:call).with(task)
      task.invoke_dynamic_block
    end

    it "returns the task" do
      (task.dynamic {}).should eq(task)
    end
  end

  describe "#invoke" do
    let(:static) { define_task('static', Rake::FileTask) }
    let!(:dynamic) { define_task('dynamic', Rake::FileTask) }
    let!(:dynamic_task) { define_task('output' => static).dynamic { ['dynamic'] } }

    it "invokes the task's static and dynamic prerequisites" do
      dynamic_task.invoke
      invoked_tasks.should include(static)
      invoked_tasks.should include(dynamic)
    end

    it "adds dynamic dependencies to its manifest entry" do
      dynamic_task.invoke
      dynamic_task.manifest_entry.deps.should == {
        'dynamic' => File.mtime('dynamic')
      }
    end

    it "adds the current task's mtime to its manifest entry" do
      dynamic_task.invoke
      dynamic_task.manifest_entry.mtime.should == File.mtime('output')
    end

    it "raises an error when there is no manifest" do
      dynamic_task.manifest = nil
      lambda { 
        dynamic_task.invoke
      }.should raise_error(Rake::Pipeline::DynamicFileTask::ManifestRequired)
    end
  end

  describe "#needed?" do
    it "is true if the task has manifest entry" do
      task.manifest_entry.should be_nil
      task.should be_needed
    end
  end

  describe "#dynamic_prerequisites" do
    def make_file(name, mtime=nil)
      touch(name)
      if mtime
        File.utime(mtime, mtime, name)
      end
    end

    it "returns an empty array if the task has no dynamic block" do
      task.dynamic_prerequisites.should == []
    end

    it "returns the result of invoking the dynamic block" do
      task.dynamic { %w[blinky] }
      task.dynamic_prerequisites.should == %w[blinky]
    end

    it "filters the task itself from the list" do
      task.dynamic { %w[output blinky] }
      task.dynamic_prerequisites.should == %w[blinky]
    end

    it "loads dependency information from the manifest first" do
      time = Time.utc(2000)
      %w[blinky output].each { |f| make_file f, time }

      manifest_entry = Rake::Pipeline::ManifestEntry.from_hash({
        "deps" => {
          "blinky" => "2000-01-01 00:00:00 +0000"
        },
        "mtime" => "2000-01-01 00:00:00 +0000"
      })

      task.dynamic { %w[] }
      task.stub(:last_manifest_entry) { manifest_entry }
      task.should_not_receive(:invoke_dynamic_block)
      task.dynamic_prerequisites.should == %w[blinky]
    end
  end

end
