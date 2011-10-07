describe "Rake::Pipeline::Filter" do
  def input_file(path, file_root=input_root)
    Rake::Pipeline::FileWrapper.new(file_root, path)
  end

  def output_file(path, file_root=output_root)
    Rake::Pipeline::FileWrapper.new(file_root, path)
  end

  let(:filter) { Rake::Pipeline::Filter.new }

  it "accepts a list of input files" do
    filter.input_files = []
    filter.input_files.should == []
  end

  it "accepts a root directory for the inputs" do
    path = File.expand_path(tmp, "app/assets")
    filter.input_root = path
    filter.input_root.should == path
  end

  it "accepts a root directory for the outputs" do
    path = File.expand_path(tmp, "filter1/app/assets")
    filter.output_root = path
    filter.output_root.should == path
  end

  it "accepts a proc to convert the input name into an output name" do
    conversion = proc { |input| input }
    filter.output_name = conversion
    filter.output_name.should == conversion
  end

  describe "using the output_name proc to converting the input names into a hash" do
    let(:input_files) { %w(jquery.js jquery-ui.js sproutcore.js) }
    let(:input_root)  { File.join(tmp, "app/assets") }
    let(:output_root) { File.join(tmp, "filter1/app/assets") }

    before do
      filter.input_root = input_root
      filter.output_root = output_root
      filter.input_files = input_files
    end

    it "with a simple output_name proc that outputs to a single file" do
      output_name = proc { |input| "application.js" }
      filter.output_name = output_name

      filter.outputs.should == {
        output_file("application.js") => 
          input_files.map { |i| input_file(i) }
      }

      filter.output_files.should == [output_file("application.js").path]
    end

    it "with a 1:1 output_name proc" do
      output_name = proc { |input| input }
      filter.output_name = output_name
      outputs = filter.outputs

      outputs.keys.should == input_files.map { |f| output_file(f) }
      outputs.values.should == input_files.map { |f| [input_file(f)] }

      filter.output_files.should == input_files.map { |f| output_file(f).path }
    end

    it "with a more complicated proc" do
      output_name = proc { |input| input.split(/[-.]/, 2).first + ".js" }
      filter.output_name = output_name
      outputs = filter.outputs

      outputs.keys.should == [output_file("jquery.js"), output_file("sproutcore.js")]
      outputs.values.should == [[input_file("jquery.js"), input_file("jquery-ui.js")], [input_file("sproutcore.js")]]

      filter.output_files.should == [output_file("jquery.js").path, output_file("sproutcore.js").path]
    end
  end

  describe "generates rake tasks" do
    class TestFilter < Rake::Pipeline::Filter
      attr_accessor :generate_output_block

      def generate_output(inputs, output)
        generate_output_block.call(inputs, output)
      end
    end

    def input_path(path)
      File.join(input_root, path)
    end

    let(:filter)      { TestFilter.new }
    let(:input_files) { %w(javascripts/jquery.js javascripts/jquery-ui.js javascripts/sproutcore.js) }
    let(:input_root)  { File.join(tmp, "app/assets") }
    let(:output_root) { File.join(tmp, "filter1/app/assets") }

    before do
      Rake.application = Rake::Application.new
      filter.input_root = input_root
      filter.output_root = output_root
      filter.input_files = input_files
    end

    def output_task(path)
      Rake::FileTask.define_task(File.join(output_root, path))
    end

    def input_task(path)
      Rake::FileTask.define_task(File.join(input_root, path))
    end

    it "with a simple output_name proc that outputs to a single file" do
      filter_runs = 0

      filter.output_name = proc { |input| "javascripts/application.js" }
      filter.generate_output_block = proc do |inputs, output|
        inputs.should == input_files.map { |i| input_file(i) }
        output.should == output_file("javascripts/application.js")

        filter_runs += 1
      end

      tasks = filter.rake_tasks
      tasks.should == [output_task("javascripts/application.js")]
      tasks[0].prerequisites.should == input_files.map { |i| input_path(i) }

      tasks.each(&:invoke)

      filter_runs.should == 1
    end

    it "with a 1:1 output_name proc" do
      filter_runs = 0

      filter.output_name = proc { |input| input }
      filter.generate_output_block = proc do |inputs, output|
        inputs.should == [input_file(input_files[filter_runs])]
        output.should == output_file(input_files[filter_runs])

        filter_runs += 1
      end

      tasks = filter.rake_tasks
      tasks.should == input_files.map { |path| output_task(path) }
      tasks.each_with_index do |task, index|
        task.prerequisites.should == [input_path(input_files[index])]
      end

      tasks.each(&:invoke)

      filter_runs.should == 3
    end

    it "with a more complicated proc" do
      filter_runs = 0

      filter.output_name = proc { |input| input.match(%r{javascripts/[^-.]*})[0] + ".js" }
      filter.generate_output_block = proc do |inputs, output|
        if output.path == "javascripts/jquery.js"
          inputs.should == [input_file("javascripts/jquery.js"), input_file("javascripts/jquery-ui.js")]
          output.should == output_file("javascripts/jquery.js")
        elsif output.path == "javascripts/sproutcore.js"
          inputs.should == [input_file("javascripts/sproutcore.js")]
          output.should == output_file("javascripts/sproutcore.js")
        else
          flunk
        end

        filter_runs += 1
      end

      tasks = filter.rake_tasks
      tasks.should == [output_task("javascripts/jquery.js"), output_task("javascripts/sproutcore.js")]

      tasks[0].prerequisites.should == [
        input_path("javascripts/jquery.js"),
        input_path("javascripts/jquery-ui.js")
      ]

      tasks[1].prerequisites.should == [input_path("javascripts/sproutcore.js")]

      tasks.each(&:invoke)

      filter_runs.should == 2
    end
  end
end
