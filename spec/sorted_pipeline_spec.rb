describe "Rake::Pipeline" do
  include Rake::Pipeline::SpecHelpers::InputHelpers

  let(:pipeline) { Rake::Pipeline::SortedPipeline.new }

  it "accepts a comparator" do
    pipeline.comparator = :foo
    pipeline.comparator.should == :foo
  end

  it "accepts a pipeline for mimicing the filter api" do
    container = Rake::Pipeline.new
    pipeline.pipeline = container
    pipeline.pipeline.should == container
  end

  it "uses sorted input files for #output_files" do
    # Reverse sort
    pipeline.comparator = proc { |f1, f2|
      f2 <=> f1
    }

    pipeline.input_files = [input_file("jquery.js"), input_file("jquery_ui.js")]
    pipeline.output_files.first.path.should == 'jquery_ui.js'
    pipeline.output_files.last.path.should == 'jquery.js'
  end
end
