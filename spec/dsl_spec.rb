describe "Rake::Pipeline::DSL" do
  ConcatFilter = Rake::Pipeline::SpecHelpers::Filters::ConcatFilter

  let(:pipeline) { Rake::Pipeline.new }
  let(:dsl) { Rake::Pipeline::DSL.new(pipeline) }

  before do
    pipeline.input_root = "."
  end

  it "accepts a pipeline in its constructor" do
    dsl.pipeline.should == pipeline
  end

  describe "#input" do
    it "configures the pipeline's input_root" do
      dsl.input "/app"
      pipeline.input_root.should == "/app"
    end

    it "configures the pipeline's input_glob" do
      dsl.input "/app", "*.js"
      pipeline.input_glob.should == "*.js"
    end

    it "defaults the pipeline's input_glob to **/*" do
      dsl.input "/app"
      pipeline.input_glob.should == "**/*"
    end
  end

  describe "#filter" do

    it "adds a new instance of the filter class to the pipeline's filters" do
      pipeline.filters.should be_empty
      dsl.filter ConcatFilter
      pipeline.filters.should_not be_empty
      pipeline.filters.last.should be_kind_of(ConcatFilter)
    end

    it "takes a block to configure the filter's output file names" do
      generator = proc { |input| "main.js" }
      dsl.filter(ConcatFilter, &generator)
      pipeline.filters.last.output_name_generator.should == generator
    end

    it "passes any extra arguments to the filter's constructor" do
      filter_class = Class.new(Rake::Pipeline::Filter) do
        attr_reader :args
        def initialize(*args)
          @args = args
        end
      end

      dsl.filter filter_class, "foo", "bar"
      pipeline.filters.last.args.should == %w(foo bar)
    end
  end

  describe "#match" do
    it "creates a Matcher for the given glob" do
      matcher = dsl.match("*.glob") {}
      matcher.should be_kind_of(Rake::Pipeline::Matcher)
      matcher.glob.should == "*.glob"
    end

    it "adds the new matcher to the pipeline's filters" do
      matcher = dsl.match("*.glob") {}
      pipeline.filters.last.should == matcher
    end
  end

  describe "#output" do
    it "configures the pipeline's output_root" do
      dsl.output "/path/to/output"
      pipeline.output_root.should == "/path/to/output"
    end
  end

  describe "#tmpdir" do
    it "configures the pipeline's tmpdir" do
      dsl.tmpdir "/temporary"
      pipeline.tmpdir.should == "/temporary"
    end
  end
end
