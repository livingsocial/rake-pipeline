require 'spec_helper'

describe Rake::Pipeline::DynamicFileTask do
  subject { Rake::Pipeline::DynamicFileTask.define_task('inky') }

  describe "#dynamic" do
    it "saves a block that can be called later with #invoke_dynamic_block" do
      block = proc {}
      subject.dynamic(&block)
      block.should_receive(:call).with(subject)
      subject.invoke_dynamic_block
    end
  end

  describe "#dynamic_prerequisites" do
    it "returns the result of invoking the dynamic block" do
      subject.dynamic { ['blinky'] }
      subject.dynamic_prerequisites.should == ['blinky']
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

    subject do
      Rake::Pipeline::DynamicFileTask.define_task('output' => static, &task_proc)
    end

    before do
      subject.dynamic { ['dynamic'] }
    end

    after do
      # Clean out all defined tasks after each test runs
      Rake.application = Rake::Application.new
    end

    it "invokes the task's static and dynamic prerequisites" do
      subject.invoke
      invoked_tasks.should include(static)
      invoked_tasks.should include(dynamic)
    end

    it "adds dynamic dependencies to its manifest entry" do
      subject.manifest_entry.should be_nil
      subject.invoke
      subject.manifest_entry.deps.should == {
        'dynamic' => File.mtime('dynamic')
      }
    end

    it "adds the current task's mtime to its manifest entry" do
      subject.manifest_entry.should be_nil
      subject.invoke
      subject.manifest_entry.mtime.should == File.mtime('output')
    end
  end

  describe "#needed?" do
    it "is true if the task has no previous manifest entry" do
      subject.last_manifest_entry.should be_nil
      subject.should be_needed
    end
  end
end
