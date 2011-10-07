describe "Rake::Pipeline::Filter" do
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

    def input_file(path, file_root=input_root)
      Rake::Pipeline::FileWrapper.new(file_root, path)
    end

    def output_file(path, file_root=output_root)
      Rake::Pipeline::FileWrapper.new(file_root, path)
    end

    it "with a simple output_name proc that outputs to a single file" do
      output_name = proc { |input| "application.js" }
      filter.output_name = output_name

      filter.outputs.should == {
        output_file("application.js") => 
          input_files.map { |i| input_file(i) }
      }
    end

    it "with a 1:1 output_name proc" do
      output_name = proc { |input| input }
      filter.output_name = output_name
      outputs = filter.outputs

      outputs.keys.should == input_files.map { |f| output_file(f) }
      outputs.values.should == input_files.map { |f| [input_file(f)] }
    end

    it "with a more complicated proc" do
      output_name = proc { |input| input.split(/[-.]/, 2).first + ".js" }
      filter.output_name = output_name
      outputs = filter.outputs

      outputs.keys.should == [output_file("jquery.js"), output_file("sproutcore.js")]
      outputs.values.should == [[input_file("jquery.js"), input_file("jquery-ui.js")], [input_file("sproutcore.js")]]
    end
  end
end
