inputs = {

"app/javascripts/jquery.js" => <<-HERE,
var jQuery = {};
HERE

"app/javascripts/sproutcore.js" => <<-HERE
var SC = {};
assert(SC);
SC.hi = function() { console.log("hi"); };
HERE

}

expected_output = <<-HERE
var jQuery = {};
var SC = {};

SC.hi = function() { console.log("hi"); };
HERE

describe "A realistic pipeline" do
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

  before do
    Rake.application = Rake::Application.new
  end

  it "can successfully apply filters" do
    inputs.each do |name, string|
      mkdir_p File.dirname(File.join(tmp, name))
      File.open(File.join(tmp, name), "w") { |file| file.write(string) }
    end

    concat = ConcatFilter.new
    concat.input_root = tmp
    concat.input_files = inputs.keys
    concat.output_root = File.join(tmp, "concat_filter")
    concat.output_name = proc { |input| "javascripts/application.js" }

    strip_asserts = StripAssertsFilter.new
    strip_asserts.input_root = concat.output_root
    strip_asserts.input_files = concat.outputs.keys.map { |file| file.path }
    strip_asserts.output_root = File.join(tmp, "public")
    strip_asserts.output_name = proc { |input| input }

    concat.rake_tasks
    Rake::Task.define_task(:default => strip_asserts.rake_tasks)
    Rake.application[:default].invoke

    output = File.join(tmp, "public/javascripts/application.js")
    File.exists?(output).should be_true
    File.read(output).should == expected_output
  end
end
