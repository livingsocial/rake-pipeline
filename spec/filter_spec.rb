describe "Rake::Pipeline::Filter" do
  let(:filter) { Rake::Pipeline::Filter.new }

  it "accepts a list of input files" do
    filter.input_files = []
    filter.input_files.should == []
  end

  it "accepts a proc to convert the input name into an output name" do
    conversion = proc { |input| input }
    filter.output_name = conversion
    filter.output_name.should == conversion
  end
end
