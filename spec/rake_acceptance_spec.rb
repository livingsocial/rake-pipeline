require "rake-pipeline/filters"

describe "A realistic pipeline" do

INPUTS = {

"app/javascripts/jquery.js" => <<-HERE,
var jQuery = {};
HERE

"app/javascripts/sproutcore.js" => <<-HERE,
var SC = {};
assert(SC);
SC.hi = function() { console.log("hi"); };
HERE

"app/stylesheets/jquery.css" => <<-HERE,
#jquery {
  color: red;
}
HERE

"app/stylesheets/sproutcore.css" => <<-HERE,
#sproutcore {
  color: green;
}
HERE

"app/index.html" => <<-HERE
<html></html>
HERE

}

EXPECTED_JS_OUTPUT = <<-HERE
var jQuery = {};
var SC = {};

SC.hi = function() { console.log("hi"); };
HERE

EXPECTED_CSS_OUTPUT = <<-HERE
#jquery {
  color: red;
}
#sproutcore {
  color: green;
}
HERE

EXPECTED_HTML_OUTPUT = <<-HERE
<html></html>
HERE

  before do
    Rake.application = Rake::Application.new

    INPUTS.each do |name, string|
      mkdir_p File.dirname(File.join(tmp, name))
      File.open(File.join(tmp, name), "w") { |file| file.write(string) }
    end
  end

  def input_wrapper(path)
    Rake::Pipeline::FileWrapper.new(tmp, path)
  end

  def output_should_exist(expected = EXPECTED_JS_OUTPUT)
    output = File.join(tmp, "public/javascripts/application.js")
    temp   = File.join(tmp, "temporary")

    File.exists?(output).should be_true
    File.exists?(temp).should be_true

    File.read(output).should == expected
  end

  concat_filter = Rake::Pipeline::ConcatFilter
  strip_asserts_filter = Rake::Pipeline::SpecHelpers::Filters::StripAssertsFilter

  it "can successfully apply filters" do
    concat = concat_filter.new
    concat.input_files = INPUTS.keys.select { |key| key =~ /javascript/ }.map { |file| input_wrapper(file) }
    concat.output_root = File.join(tmp, "temporary", "concat_filter")
    concat.output_name_generator = proc { |input| "javascripts/application.js" }

    strip_asserts = strip_asserts_filter.new
    strip_asserts.input_files = concat.output_files
    strip_asserts.output_root = File.join(tmp, "public")
    strip_asserts.output_name_generator = proc { |input| input }

    concat.generate_rake_tasks
    Rake::Task.define_task(:default => strip_asserts.generate_rake_tasks)
    Rake.application[:default].invoke

    output_should_exist
  end

  it "can be configured using the pipeline" do
    pipeline = Rake::Pipeline.new
    pipeline.input_root = File.expand_path(tmp)
    pipeline.output_root = File.expand_path("public")
    pipeline.input_glob = "app/javascripts/*.js"
    pipeline.tmpdir = "temporary"

    concat = concat_filter.new
    concat.output_name_generator = proc { |input| "javascripts/application.js" }

    strip_asserts = strip_asserts_filter.new
    strip_asserts.output_name_generator = proc { |input| input }

    pipeline.add_filters(concat, strip_asserts)
    pipeline.invoke

    output_should_exist
  end

  describe "using the pipeline DSL" do

    attr_reader :pipeline

    shared_examples_for "the pipeline DSL" do
      it "can be configured using the pipeline DSL" do
        pipeline.invoke
        output_should_exist
      end

      it "can be configured using the pipeline DSL with an alternate Rake application" do
        pipeline.rake_application = Rake::Application.new
        pipeline.invoke
        output_should_exist
      end

      it "can be invoked repeatedly to reflected updated changes" do
        pipeline.invoke
        age_existing_files

        File.open(File.join(tmp, "app/javascripts/jquery.js"), "w") do |file|
          file.write "var jQuery = {};\njQuery.trim = function() {};\n"
        end

        expected = <<-HERE.gsub(/^ {10}/, '')
          var jQuery = {};
          jQuery.trim = function() {};
          var SC = {};

          SC.hi = function() { console.log("hi"); };
        HERE

        pipeline.invoke

        output_should_exist(expected)
      end

      it "can be restarted to reflect new files" do
        pipeline.invoke
        age_existing_files

        File.open(File.join(tmp, "app/javascripts/history.js"), "w") do |file|
          file.write "var History = {};\n"
        end

        pipeline.invoke_clean

        expected = <<-HERE.gsub(/^ {10}/, '')
          var History = {};
          var jQuery = {};
          var SC = {};

          SC.hi = function() { console.log("hi"); };
        HERE

        output_should_exist(expected)
      end
    end

    describe "the raw pipeline DSL" do
      it_behaves_like "the pipeline DSL"

      before do
        @pipeline = Rake::Pipeline.build do
          tmpdir "temporary"
          input tmp, "app/javascripts/*.js"
          filter(concat_filter) { "javascripts/application.js" }
          filter(strip_asserts_filter) { |input| input }
          output "public"
        end
      end
    end

    describe "the raw pipeline DSL" do
      it_behaves_like "the pipeline DSL"

      before do
        @pipeline = Rake::Pipeline.build do
          tmpdir "temporary"
          input tmp, "app/javascripts/*.js"
          filter concat_filter, "javascripts/application.js"
          filter strip_asserts_filter
          output "public"
        end
      end
    end

    describe "using the matcher spec" do

      def output_should_exist(expected=EXPECTED_JS_OUTPUT)
        super

        css = File.join(tmp, "public/stylesheets/application.css")

        File.exists?(css).should be_true
        File.read(css).should == EXPECTED_CSS_OUTPUT

        html = File.join(tmp, "public/index.html")
        File.exists?(html).should be_true
        File.read(html).should == EXPECTED_HTML_OUTPUT
      end

      it_behaves_like "the pipeline DSL"

      before do
        @pipeline = Rake::Pipeline.build do
          tmpdir "temporary"
          input File.join(tmp, "app"), "**/*.{js,css,html}"
          output "public"

          match "**/*.js" do
            filter strip_asserts_filter
            filter concat_filter, "javascripts/application.js"
          end

          match "**/*.css" do
            filter concat_filter, "stylesheets/application.css"
          end
        end
      end
    end
  end
end
