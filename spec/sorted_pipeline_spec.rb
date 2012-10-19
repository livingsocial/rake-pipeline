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
    # only 2 files in this test. Return 1 so the
    # first comparison reorders the array
    pipeline.comparator = proc { |f1, f2|
      1
    }

    pipeline.input_files = [input_file("jquery.js"), input_file("jquery_ui.js")]
    pipeline.output_files.first.path.should == 'jquery_ui.js'
    pipeline.output_files.last.path.should == 'jquery.js'
  end
end
