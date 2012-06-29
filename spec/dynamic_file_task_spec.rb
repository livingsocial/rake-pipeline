require 'spec_helper'

describe Rake::Pipeline::DynamicFileTask do
  let!(:dynamic_task) { Rake::Pipeline::DynamicFileTask.define_task('inky') }

  describe "#dynamic" do
    it "saves a block that can be called later with #invoke_dynamic_block" do
      block = proc {}
      dynamic_task.dynamic(&block)
      block.should_receive(:call).with(dynamic_task)
      dynamic_task.invoke_dynamic_block
    end

    it "returns the task" do
      (dynamic_task.dynamic {}).should eq(dynamic_task)
    end
  end

  describe "#dynamic_prerequisites" do
    it "returns the result of invoking the dynamic block" do
      dynamic_task.dynamic { ['blinky'] }
      dynamic_task.dynamic_prerequisites.should == ['blinky']
    end
  end

  describe "#invoke" do
    let(:invoked_tasks) { [] }

    let(:task_proc) {
      proc do |task|
        touch(task.name)
        invoked_tasks << task
      end
    }

    let(:static) { Rake::FileTask.define_task('static', &task_proc) }

    let!(:dynamic) { Rake::FileTask.define_task('dynamic', &task_proc) }

    let!(:dynamic_task) do
      Rake::Pipeline::DynamicFileTask.define_task('output' => static, &task_proc)
    end

    before do
      dynamic_task.dynamic { ['dynamic'] }
    end

    after do
      # Clean out all defined tasks after each test runs
      Rake.application = Rake::Application.new
    end

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
      dynamic_task.last_manifest_entry.should be_nil
      dynamic_task.should be_needed
    end
  end
end
