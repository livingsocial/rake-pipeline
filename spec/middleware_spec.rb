require "rake-pipeline/middleware"
require "rake-pipeline/filters"
require "rack/test"

describe "Rake::Pipeline Middleware" do
  include Rack::Test::Methods

  ConcatFilter = Rake::Pipeline::SpecHelpers::Filters::ConcatFilter

  class StripAssertsFilter < Rake::Pipeline::Filter
    def generate_output(inputs, output)
      inputs.each do |input|
        output.write input.read.gsub(%r{^\s*assert\(.*\)\s*;?\s*$}m, '')
      end
    end
  end

  inputs = {
    "app/javascripts/jquery.js" => "var jQuery = {};\n",

    "app/javascripts/sproutcore.js" => <<-HERE.gsub(/^ {6}/, ''),
      var SC = {};
      assert(SC);
      SC.hi = function() { console.log("hi"); };
    HERE

    "app/index.html" => "<html>HI</html>",
    "app/javascripts/index.html" => "<html>JAVASCRIPT</html>",
    "app/empty_dir" => nil
  }

  expected_output = <<-HERE.gsub(/^ {4}/, '')
    var jQuery = {};
    var SC = {};

    SC.hi = function() { console.log("hi"); };
  HERE

  app = middleware = pipeline = nil

  before do
    app = lambda { |env| [404, {}, ['not found']] }

    pipeline = Rake::Pipeline.build do
      input tmp, "app/**/*"

      match "*.js" do
        filter(ConcatFilter) { "javascripts/application.js" }
        filter(StripAssertsFilter) { |input| input }
      end

      # copy the rest
      filter(ConcatFilter) { |input| input.sub(/^app\//, '') }

      output "public"
    end

    middleware = Rake::Pipeline::Middleware.new(app, pipeline)

    inputs.each do |name, string|
      path = File.join(tmp, name)
      if string
        mkdir_p File.dirname(path)
        File.open(path, "w") { |file| file.write(string) }
      else
        mkdir_p path
      end
    end

    get "/javascripts/application.js"
  end

  let(:app) { middleware }

  it "returns files relative to the output directory" do
    last_response.should be_ok

    last_response.body.should == expected_output
    last_response.headers["Content-Type"].should == "application/javascript"
  end

  it "updates the output when files change" do
    age_existing_files

    File.open(File.join(tmp, "app/javascripts/jquery.js"), "w") do |file|
      file.write "var jQuery = {};\njQuery.trim = function() {};\n"
    end

    expected = <<-HERE.gsub(/^ {6}/, '')
      var jQuery = {};
      jQuery.trim = function() {};
      var SC = {};

      SC.hi = function() { console.log("hi"); };
    HERE

    get "/javascripts/application.js"

    last_response.body.should == expected
    last_response.headers["Content-Type"].should == "application/javascript"
  end

  it "updates the output when new files are added" do
    age_existing_files

    File.open(File.join(tmp, "app/javascripts/history.js"), "w") do |file|
      file.write "var History = {};\n"
    end

    expected = <<-HERE.gsub(/^ {6}/, '')
      var History = {};
      var jQuery = {};
      var SC = {};

      SC.hi = function() { console.log("hi"); };
    HERE

    get "/javascripts/application.js"

    last_response.body.should == expected
    last_response.headers["Content-Type"].should == "application/javascript"
  end

  it "returns index.html for directories" do
    get "/"

    last_response.body.should == "<html>HI</html>"
    last_response.headers["Content-Type"].should == "text/html"

    get "/javascripts"

    last_response.body.should == "<html>JAVASCRIPT</html>"
    last_response.headers["Content-Type"].should == "text/html"
  end

  it "ignores directories without index.html" do
    get "/empty_dir"

    last_response.body.should == "not found"
    last_response.status.should == 404
  end

  it "falls back to the app" do
    get "/zomg.notfound"

    last_response.body.should == "not found"
    last_response.status.should == 404
  end
end
