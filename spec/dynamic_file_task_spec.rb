require 'spec_helper'

describe Rake::Pipeline::DynamicFileTask do
  let(:invoked_tasks) { [] }

  def define_task(deps, klass=Rake::Pipeline::DynamicFileTask, &task_proc)
    task_proc ||= proc do |task|
      touch(task.name)
      invoked_tasks << task
    end

    klass.define_task(deps, &task_proc)
  end

  let(:task) { define_task('output') }

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
      dynamic_task.manifest_entry.should be_nil
      dynamic_task.invoke
      dynamic_task.manifest_entry.deps.should == {
        'dynamic' => File.mtime('dynamic')
      }
    end

    it "adds the current task's mtime to its manifest entry" do
      dynamic_task.manifest_entry.should be_nil
      dynamic_task.invoke
      dynamic_task.manifest_entry.mtime.should == File.mtime('output')
    end
  end

  describe "#needed?" do
    it "is true if the task has no previous manifest entry" do
      task.last_manifest_entry.should be_nil
      task.should be_needed
    end
  end

  describe "#dynamic_prerequisites" do
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
  end
end
