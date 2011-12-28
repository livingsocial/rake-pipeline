describe "Rake::Pipeline::DSL" do
  ConcatFilter = Rake::Pipeline::SpecHelpers::Filters::ConcatFilter

  let(:pipeline) { Rake::Pipeline.new }
  let(:dsl) { Rake::Pipeline::DSL.new(pipeline) }

  def filter
    pipeline.filters.last
  end

  it "accepts a pipeline in its constructor" do
    dsl.pipeline.should == pipeline
  end

  describe "#input" do
    it "adds an input to the pipeline" do
      dsl.input "/app"
      pipeline.inputs["/app"].should == '**/*'
    end

    it "configures the input's glob" do
      dsl.input "/app", "*.js"
      pipeline.inputs['/app'].should == "*.js"
    end

    it "defaults input's glob to **/*" do
      dsl.input "/app"
      pipeline.inputs['/app'].should == "**/*"
    end
  end

  describe "#filter" do

    it "adds a new instance of the filter class to the pipeline's filters" do
      pipeline.filters.should be_empty
      dsl.filter ConcatFilter
      pipeline.filters.should_not be_empty
      filter.should be_kind_of(ConcatFilter)
    end

    it "takes a block to configure the filter's output file names" do
      generator = proc { |input| "main.js" }
      dsl.filter(ConcatFilter, &generator)
      filter.output_name_generator.should == generator
    end

    it "passes any extra arguments to the filter's constructor" do
      filter_class = Class.new(Rake::Pipeline::Filter) do
        attr_reader :args
        def initialize(*args)
          @args = args
        end
      end

      dsl.filter filter_class, "foo", "bar"
      filter.args.should == %w(foo bar)
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
      filter.should == matcher
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

  describe "#concat" do
    it "creates a ConcatFilter" do
      dsl.concat "octopus"
      filter.should be_kind_of(Rake::Pipeline::ConcatFilter)
    end

    context "passed an Array first argument" do
      it "creates an OrderingConcatFilter" do
        dsl.concat ["octopus"]
        filter.should be_kind_of(Rake::Pipeline::OrderingConcatFilter)
      end
    end
  end
end
