require "rake-pipeline/filters"

describe "A realistic project" do

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

"app/index.html" => <<-HERE,
<html></html>
HERE

"app/junk.txt" => <<-HERE,
junk
HERE

"app/main.dynamic" => <<-HERE,
# main.dynamic
static content
@import("variables")
HERE

"variables.import" => <<-HERE,
$rakep = awesome
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

EXPECTED_DYNAMIC_OUTPUT = <<-HERE
# main.dynamic
static content
@import("variables")
$rakep = awesome
HERE

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
  dynamic_import_filter = Rake::Pipeline::SpecHelpers::Filters::DynamicImportFilter
  strip_asserts_filter = Rake::Pipeline::SpecHelpers::Filters::StripAssertsFilter
  memory_manifest = Rake::Pipeline::SpecHelpers::MemoryManifest

  def copy_files
    INPUTS.each do |name, string|
      mkdir_p File.dirname(File.join(tmp, name))
      File.open(File.join(tmp, name), "w") { |file| file.write(string) }
    end
  end

  before do
    Rake.application = Rake::Application.new
    copy_files
  end

  describe "a pipeline" do
    it "can successfully apply filters" do
      concat = concat_filter.new
      concat.manifest = memory_manifest.new
      concat.last_manifest = memory_manifest.new
      concat.input_files = INPUTS.keys.select { |key| key =~ /javascript/ }.map { |file| input_wrapper(file) }
      concat.output_root = File.join(tmp, "temporary", "concat_filter")
      concat.output_name_generator = proc { |input| "javascripts/application.js" }

      strip_asserts = strip_asserts_filter.new
      strip_asserts.manifest = memory_manifest.new
      strip_asserts.last_manifest = memory_manifest.new
      strip_asserts.input_files = concat.output_files
      strip_asserts.output_root = File.join(tmp, "public")
      strip_asserts.output_name_generator = proc { |input| input }

      concat.generate_rake_tasks
      Rake::Task.define_task(:default => strip_asserts.generate_rake_tasks)
      Rake.application[:default].invoke

      output_should_exist
    end

    it "supports filters with multiple outputs per input" do
      concat = concat_filter.new
      concat.manifest = memory_manifest.new
      concat.last_manifest = memory_manifest.new
      concat.input_files = INPUTS.keys.select { |key| key =~ /javascript/ }.map { |file| input_wrapper(file) }
      concat.output_root = File.join(tmp, "temporary", "concat_filter")
      concat.output_name_generator = proc { |input| [ "javascripts/application.js", input.sub(/^app\//, '') ] }

      strip_asserts = strip_asserts_filter.new
      strip_asserts.manifest = memory_manifest.new
      strip_asserts.last_manifest = memory_manifest.new
      strip_asserts.input_files = concat.output_files
      strip_asserts.output_root = File.join(tmp, "public")
      strip_asserts.output_name_generator = proc { |input| input }

      concat.generate_rake_tasks
      Rake::Task.define_task(:default => strip_asserts.generate_rake_tasks)
      Rake.application[:default].invoke

      output_should_exist

      expected_files = {
        "javascripts/jquery.js" => "var jQuery = {};\n",
        "javascripts/sproutcore.js" => "var SC = {};\n\nSC.hi = function() { console.log(\"hi\"); };\n"
      }

      expected_files.each do |file, expected|
        output_file = File.join(tmp, "public", file)
        output = nil

        lambda { output = File.read(output_file) }.should_not raise_error
        output.should == expected
      end
    end

    it "can be configured using the pipeline" do
      pipeline = Rake::Pipeline.new
      pipeline.add_input tmp, 'app/javascripts/*.js'
      pipeline.output_root = File.expand_path("public")
      pipeline.tmpdir = "temporary"

      concat = concat_filter.new
      concat.manifest = memory_manifest.new
      concat.last_manifest = memory_manifest.new
      concat.output_name_generator = proc { |input| "javascripts/application.js" }

      strip_asserts = strip_asserts_filter.new
      strip_asserts.manifest = memory_manifest.new
      strip_asserts.last_manifest = memory_manifest.new
      strip_asserts.output_name_generator = proc { |input| input }

      pipeline.add_filters(concat, strip_asserts)
      pipeline.invoke

      output_should_exist
    end

  end

  describe "using the pipeline DSL" do
    attr_reader :project

    shared_examples_for "the pipeline DSL" do
      it "can be configured using the pipeline DSL" do
        project.invoke
        output_should_exist
      end

      it "can be configured using the pipeline DSL with an alternate Rake application" do
        project.pipelines.first.rake_application = Rake::Application.new
        project.invoke
        output_should_exist
      end

      it "can be invoked repeatedly to reflected updated changes" do
        project.invoke
        age_existing_files

        if respond_to?(:update_jquery)
          update_jquery
        else
          File.open(File.join(tmp, "app/javascripts/jquery.js"), "w") do |file|
            file.write "var jQuery = {};\njQuery.trim = function() {};\n"
          end
        end

        expected = <<-HERE.gsub(/^ {10}/, '')
          var jQuery = {};
          jQuery.trim = function() {};
          var SC = {};

          SC.hi = function() { console.log("hi"); };
        HERE

        project.invoke

        output_should_exist(expected)
      end

      it "can be restarted to reflect new files" do
        project.invoke
        age_existing_files

        if respond_to?(:update_history)
          update_history
        else
          File.open(File.join(tmp, "app/javascripts/history.js"), "w") do |file|
            file.write "var History = {};\n"
          end
        end

        project.invoke

        expected = <<-HERE.gsub(/^ {10}/, '')
          var History = {};
          var jQuery = {};
          var SC = {};

          SC.hi = function() { console.log("hi"); };
        HERE

        output_should_exist(expected)
      end

      it "does not generate new files when things haven't changed" do
        output_file  = File.join(tmp, "public/javascripts/application.js")

        project.invoke
        previous_mtime = File.mtime(output_file)

        sleep 1

        project.invoke
        File.mtime(output_file).should == previous_mtime
      end
    end

    describe "the raw pipeline DSL (with block strip_asserts_filter)" do
      it_behaves_like "the pipeline DSL"

      before do
        @project = Rake::Pipeline::Project.build do
          tmpdir "temporary"
          output "public"

          input tmp, "app/javascripts/*.js" do
            concat "javascripts/application.js"
            filter(strip_asserts_filter) { |input| input }
          end
        end
      end
    end

    describe "the raw pipeline DSL (with before_filter)" do
      it_behaves_like "the pipeline DSL"

      before do
        @project = Rake::Pipeline::Project.build do
          tmpdir "temporary"
          output "public"

          before_filter Rake::Pipeline::ConcatFilter, "javascripts/application.js"

          input tmp, "app/javascripts/*.js" do
            filter strip_asserts_filter
          end
        end
      end
    end

    describe "the raw pipeline DSL (with simple strip_asserts_filter)" do
      it_behaves_like "the pipeline DSL"

      before do
        @project = Rake::Pipeline::Project.build do
          tmpdir "temporary"
          output "public"

          input tmp, "app/javascripts/*.js" do
            concat "javascripts/application.js"
            filter strip_asserts_filter
          end
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

        junk = File.join(tmp, "public/junk.txt")
        File.exists?(junk).should be_false
      end

      it_behaves_like "the pipeline DSL"

      before do
        @project = Rake::Pipeline::Project.build do
          tmpdir "temporary"
          output "public"

          input File.join(tmp, "app") do
            match "**/*.js" do
              filter strip_asserts_filter
              concat "javascripts/application.js"
            end

            match "**/*.css" do
              concat "stylesheets/application.css"
            end

            match "**/*.html" do
              concat
            end
          end
        end
      end
    end

    describe "using multiple pipelines (with after_filters)" do
      def output_should_exist(expected=EXPECTED_JS_OUTPUT)
        super

        css = File.join(tmp, "public/stylesheets/application.css")

        File.exists?(css).should be_true
        File.read(css).should == EXPECTED_CSS_OUTPUT

        html = File.join(tmp, "public/index.html")
        File.exists?(html).should be_true
        File.read(html).should == EXPECTED_HTML_OUTPUT

        junk = File.join(tmp, "public/junk.txt")
        File.exists?(junk).should be_false
      end

      it_behaves_like "the pipeline DSL"

      before do
        @project = Rake::Pipeline::Project.build do
          tmpdir "temporary"
          output "public"

          app_dir = File.join(tmp, "app")

          after_filter Rake::Pipeline::ConcatFilter do |input|
            ext = File.extname(input)

            case ext
            when ".js"
              "javascripts/application.js"
            when ".css"
              "stylesheets/application.css"
            when ".html"
              input
            end
          end

          input app_dir, "**/*.js" do
            filter strip_asserts_filter
          end

          input app_dir, "**/*.css"

          input app_dir, "**/*.html"
        end
      end
    end

    describe "using multiple pipelines" do
      def output_should_exist(expected=EXPECTED_JS_OUTPUT)
        super

        css = File.join(tmp, "public/stylesheets/application.css")

        File.exists?(css).should be_true
        File.read(css).should == EXPECTED_CSS_OUTPUT

        html = File.join(tmp, "public/index.html")
        File.exists?(html).should be_true
        File.read(html).should == EXPECTED_HTML_OUTPUT

        junk = File.join(tmp, "public/junk.txt")
        File.exists?(junk).should be_false
      end

      it_behaves_like "the pipeline DSL"

      before do
        @project = Rake::Pipeline::Project.build do
          tmpdir "temporary"
          output "public"

          app_dir = File.join(tmp, "app")

          input app_dir, "**/*.js" do
            filter strip_asserts_filter
            concat "javascripts/application.js"
          end

          input app_dir, "**/*.css" do
            concat "stylesheets/application.css"
          end

          input app_dir, "**/*.html" do
            concat
          end
        end
      end
    end

    describe "using the matcher spec (with multiple inputs to a single pipeline)" do
      it_behaves_like "the pipeline DSL"

      def tmp1
        File.join(tmp, 'tmp1')
      end

      def tmp2
        File.join(tmp, 'tmp2')
      end

      def update_jquery
        File.open(File.join(tmp1, "app/javascripts/jquery.js"), "w") do |file|
          file.write "var jQuery = {};\njQuery.trim = function() {};\n"
        end
      end

      def update_history
        File.open(File.join(tmp1, "app/javascripts/history.js"), "w") do |file|
          file.write "var History = {};\n"
        end
      end

      def copy_files
        INPUTS.each do |name, string|
          file = name =~ /\.js$/ ? File.join(tmp1, name) : File.join(tmp2, name)

          mkdir_p File.dirname(file)
          File.open(file, "w") { |f| f.write(string) }
        end
      end

      def output_should_exist(expected=EXPECTED_JS_OUTPUT)
        super

        css = File.join(tmp, "public/stylesheets/application.css")

        File.exists?(css).should be_true
        File.read(css).should == EXPECTED_CSS_OUTPUT

        html = File.join(tmp, "public/index.html")
        File.exists?(html).should be_true
        File.read(html).should == EXPECTED_HTML_OUTPUT

        junk = File.join(tmp, "public/junk.txt")
        File.exists?(junk).should be_false
      end

      before do
        tmp1 = self.tmp1
        tmp2 = self.tmp2

        @project = Rake::Pipeline::Project.build do
          tmpdir "temporary"
          output "public"

          inputs [File.join(tmp1, "app"), File.join(tmp2, "app")] do
            match "**/*.js" do
              filter strip_asserts_filter
              concat "javascripts/application.js"
            end

            match "**/*.css" do
              concat "stylesheets/application.css"
            end

            match "**/*.html" do
              concat
            end
          end
        end
      end
    end
  end

  describe "Dynamic dependencies" do
    shared_examples_for "a pipeline with dynamic files" do
      it "should handle changes in dynamic imports" do
        project.invoke

        content = File.read output_file

        content.should == EXPECTED_DYNAMIC_OUTPUT

        sleep 1

        imported_file = File.join tmp, "variables.import"

        File.open imported_file, "w" do |f| 
          f.write "true to trance"
        end

        project.invoke
        content = File.read output_file

        content.should include("true to trance")
      end

      it "should handle changes in dynamic source files" do
        project.invoke

        content = File.read output_file

        content.should == EXPECTED_DYNAMIC_OUTPUT

        sleep 1

        imported_file = File.join tmp, "app/main.dynamic"

        File.open imported_file, "w" do |f| 
          f.write "true to trance"
        end

        project.invoke
        content = File.read output_file

        content.should == "true to trance"
      end

      it "should not regenerate files when nothing changes" do
        project.invoke
        previous_mtime = File.mtime output_file
        sleep 1 ; project.invoke

        File.mtime(output_file).should == previous_mtime
      end
    end

    describe "direct dependencies" do
      let(:project) do
        Rake::Pipeline::Project.build do
          tmpdir "temporary"
          output "public"

          input tmp, "app/*.dynamic" do
            filter dynamic_import_filter
          end
        end
      end

      let(:output_file) { File.join tmp, "public", "app/main.dynamic" }

      it_should_behave_like "a pipeline with dynamic files"
    end

    describe "transitive dependencies" do
      let(:project) do
        Rake::Pipeline::Project.build do
          tmpdir "temporary"
          output "public"

          input tmp, "app/*.dynamic" do
            filter dynamic_import_filter
            concat "application.dyn"
          end
        end
      end

      let(:output_file) { File.join tmp, "public", "application.dyn" }

      it_should_behave_like "a pipeline with dynamic files"
    end
  end

  it "should work with nested matchers" do
    project = Rake::Pipeline::Project.build do
      tmpdir "temporary"
      output "public"

      input tmp, "app/**/*.js" do
        match "**/*" do
          match "**/*.js" do
            filter strip_asserts_filter
            concat "javascripts/application.js"
          end
        end
      end
    end

    project.invoke

    output_should_exist
  end
end
