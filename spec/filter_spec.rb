describe "Rake::Pipeline::Filter" do
  def input_file(path, file_root=input_root)
    Rake::Pipeline::FileWrapper.new(file_root, path)
  end

  def output_file(path, file_root=output_root)
    Rake::Pipeline::FileWrapper.new(file_root, path)
  end

  let(:filter)      { Rake::Pipeline::Filter.new }
  let(:input_root)  { File.join(tmp, "app/assets") }
  let(:output_root) { File.join(tmp, "filter1/app/assets") }
  let(:input_files) do
    %w(jquery.js jquery-ui.js ember.js).map { |f| input_file(f) }
  end

  it "accepts a series of FileWrapper objects for the input" do
    filter.input_files = input_files
    filter.input_files.should == input_files
  end

  it "accepts a root directory for the outputs" do
    path = File.expand_path(tmp, "filter1/app/assets")
    filter.output_root = path
    filter.output_root.should == path
  end

  it "accepts a Rake::Application to install tasks into" do
    app = Rake::Application.new
    filter.rake_application = app
    filter.rake_application.should == app
  end

  it "makes Rake.application the default rake_application" do
    filter.rake_application.should == Rake.application
  end

  it "accepts a proc to convert the input name into an output name" do
    conversion = proc { |input| input }
    filter.output_name_generator = conversion
    filter.output_name_generator.should == conversion
  end

  it "accepts a block constructor argument to convert the input name into an output name" do
    conversion = proc { |input| "application.js" }
    new_filter = Rake::Pipeline::Filter.new(&conversion)
    new_filter.output_name_generator.should == conversion
  end

  it "knows about its containing pipeline" do
    pipeline = Rake::Pipeline.new
    filter = Rake::Pipeline::Filter.new
    pipeline.add_filter(filter)
    filter.pipeline.should == pipeline
  end

  describe "using the output_name proc to converting the input names into a hash" do
    before do
      filter.output_root = output_root
      filter.input_files = input_files
    end

    it "with a simple output_name proc that outputs to a single file" do
      output_name_generator = proc { |input| "application.js" }
      filter.output_name_generator = output_name_generator

      filter.outputs.should == {
        output_file("application.js") => input_files
      }

      filter.output_files.should == [output_file("application.js")]
    end

    it "with more than one output per input" do
      output_name_generator = proc { |input| [ input, "application.js" ] }
      filter.output_name_generator = output_name_generator
      outputs = filter.outputs

      outputs = input_files.inject({}) do |hash, input|
        hash.merge output_file(input.path) => [ input ]
      end

      filter.outputs.should == { output_file("application.js") => input_files }.merge(outputs)
      filter.output_files.sort.should ==
        ([ output_file("application.js") ] + input_files.map { |f| output_file(f.path) }).sort
    end

    it "with a 1:1 output_name proc" do
      output_name_generator = proc { |input| input }
      filter.output_name_generator = output_name_generator
      outputs = filter.outputs

      outputs.keys.sort.should == input_files.map { |f| output_file(f.path) }.sort
      outputs.values.flatten.sort.should == input_files.sort

      filter.output_files.should == input_files.map { |file| output_file(file.path) }
    end

    it "with a more complicated proc" do
      output_name_generator = proc { |input| input.split(/[-.]/, 2).first + ".js" }
      filter.output_name_generator = output_name_generator
      outputs = filter.outputs

      outputs.keys.sort.should == [output_file("ember.js"), output_file("jquery.js")]
      outputs.values.sort.should == [[input_file("ember.js")], [input_file("jquery.js"), input_file("jquery-ui.js")]]

      filter.output_files.should == [output_file("jquery.js"), output_file("ember.js")]
    end
  end

  describe "generates rake tasks" do
    class TestFilter < Rake::Pipeline::Filter
      attr_accessor :generate_output_block

      def generate_output(inputs, output)
        generate_output_block.call(inputs, output)
      end

      def additional_dependencies(input)
        return [File.join(input.root, "extras", input.path)]
      end
    end

    let(:filter)      { TestFilter.new }
    let(:input_root)  { File.join(tmp, "app/assets") }
    let(:output_root) { File.join(tmp, "filter1/app/assets") }
    let(:input_files) do
      %w(jquery.js jquery-ui.js ember.js).map do |file|
        input_file("javascripts/#{file}")
      end
    end

    before do
      Rake.application = Rake::Application.new
      filter.output_root = output_root
      filter.input_files = input_files
    end

    def output_task(path, app=Rake.application)
      app.define_task(Rake::FileTask, File.join(output_root, path))
    end

    def input_task(path)
      Rake::FileTask.define_task(File.join(input_root, path))
    end

    it "does not generate Rake tasks onto Rake.application if an alternate application is supplied" do
      app = Rake::Application.new
      filter.rake_application = app
      filter.output_name_generator = proc { |input| input }
      filter.generate_rake_tasks
      tasks = filter.rake_tasks

      input_files.each do |file|
        task = output_task(file.path, app)
        tasks.include?(task).should == true
        Rake.application.tasks.include?(task).should == false
        app.tasks.include?(task).should == true
      end
    end

    it "with a simple output_name proc that outputs to a single file" do
      filter_runs = 0

      filter.output_name_generator = proc { |input| "javascripts/application.js" }
      filter.generate_output_block = proc do |inputs, output|
        inputs.should == input_files
        output.should == output_file("javascripts/application.js")

        filter_runs += 1
      end

      filter.generate_rake_tasks
      tasks = filter.rake_tasks
      tasks.should == [output_task("javascripts/application.js")]
      tasks[0].prerequisites.should == input_files.map { |i| [i.fullpath, File.join(i.root, "extras", i.path)] }.flatten

      tasks.each(&:invoke)

      filter_runs.should == 1
    end

    it "with an output_name proc that takes two arguments" do
      filter.output_name_generator = proc { |path, input|
        input.path.upcase
      }

      filter.outputs.keys.map(&:path).should include('JAVASCRIPTS/JQUERY.JS')
      filter.output_files.map(&:path).should include('JAVASCRIPTS/JQUERY.JS')
    end

    it "with a 1:1 output_name proc" do
      filter_runs = 0

      filter.output_name_generator = proc { |input| input }
      filter.generate_output_block = proc do |inputs, output|
        inputs.should == [input_file(output.path)]

        filter_runs += 1
      end

      filter.generate_rake_tasks
      tasks = filter.rake_tasks
      tasks.sort.should == input_files.map { |file| output_task(file.path) }.sort
      tasks.each do |task|
        name = task.name.sub(/^#{Regexp.escape(output_root)}/, '')
        prereq = File.join(input_root, name)
        extra_prereq = File.join(input_root, "extras", name)
        task.prerequisites.should == [prereq, extra_prereq]
      end

      tasks.each(&:invoke)

      filter_runs.should == 3
    end

    it "with a more complicated proc" do
      filter_runs = 0

      filter.output_name_generator = proc { |input| input.match(%r{javascripts/[^-.]*})[0] + ".js" }
      filter.generate_output_block = proc do |inputs, output|
        if output.path == "javascripts/jquery.js"
          inputs.should == [input_file("javascripts/jquery.js"), input_file("javascripts/jquery-ui.js")]
          output.should == output_file("javascripts/jquery.js")
        elsif output.path == "javascripts/ember.js"
          inputs.should == [input_file("javascripts/ember.js")]
          output.should == output_file("javascripts/ember.js")
        else
          flunk
        end

        filter_runs += 1
      end

      filter.generate_rake_tasks
      tasks = filter.rake_tasks
      tasks.sort.should == [output_task("javascripts/jquery.js"), output_task("javascripts/ember.js")].sort

      tasks.sort[0].prerequisites.should == [
        File.join(input_root, "javascripts/ember.js"),
        File.join(input_root, "extras/javascripts/ember.js")
      ]

      tasks.sort[1].prerequisites.should == [
        File.join(input_root, "javascripts/jquery.js"),
        File.join(input_root, "extras/javascripts/jquery.js"),
        File.join(input_root, "javascripts/jquery-ui.js"),
        File.join(input_root, "extras/javascripts/jquery-ui.js")
      ]

      tasks.each(&:invoke)

      filter_runs.should == 2
    end
  end
end
