describe "Rake::Pipeline" do
  let(:pipeline) { Rake::Pipeline.new }

  class ConcatFilter < Rake::Pipeline::Filter
    def generate_output(inputs, output)
      inputs.each do |input|
        output.write input.read
      end
    end
  end

  class StripAssertsFilter < Rake::Pipeline::Filter
    def generate_output(inputs, output)
      inputs.each do |input|
        output.write input.read.gsub(%r{^\s*assert\(.*\)\s*;?\s*$}m, '')
      end
    end
  end

  it "accepts a input root" do
    pipeline.input_root = "app/assets"
    pipeline.input_root.should == "app/assets"
  end

  it "raises an exception on #relative_input_files if input_files are not provided" do
    pipeline.input_root = "app/assets"
    lambda { pipeline.relative_input_files }.should raise_error(Rake::Pipeline::Error)
  end

  it "raises an exception on #relative_input_files if input_root is not provided" do
    pipeline.input_files = Dir["app/assets/javascripts/**/*.js"]
    lambda { pipeline.relative_input_files }.should raise_error(Rake::Pipeline::Error)
  end

  it "accepts an output directory" do
    pipeline.output_root = "public"
    pipeline.output_root.should == "public"
  end

  it "can have filters added to it" do
    filter = ConcatFilter.new
    pipeline.filters << filter
    pipeline.filters.should == [filter]
  end

  describe "when working with input" do
    files = %w(javascripts/jquery.js javascripts/sproutcore.js)

    before do
      files.each do |filename|
        mkdir_p File.join(tmp, "app/assets", File.dirname(filename))

        File.open(File.join(tmp, "app/assets", filename), "w") do |file|
          file.write "// This is #{filename}\n"
        end
      end

      inputs = Dir["app/assets/javascripts/**/*.js"]
      pipeline.input_root = "app/assets"
      pipeline.input_files = inputs
      pipeline.output_root = "public"
    end

    it "accepts a list of relative input files" do
      pipeline.relative_input_files.should == files
    end

    it "configures the filters with outputs and inputs with #build" do
      concat = ConcatFilter.new
      concat.output_name = proc { |input| "javascripts/application.js" }

      strip_asserts = StripAssertsFilter.new
      strip_asserts.output_name = proc { |input| input }

      pipeline.filters << concat << strip_asserts
      pipeline.build

      concat.input_root.should == File.expand_path(pipeline.input_root)
      concat.input_files.should == pipeline.relative_input_files
      concat.output_root.should == strip_asserts.input_root

      strip_asserts.input_files.should == ["javascripts/application.js"]
      strip_asserts.output_root.should == File.expand_path(pipeline.output_root)
    end
  end
end
