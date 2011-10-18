require "rake-pipeline/middleware"
require "rake-pipeline/filters"
require "rack/test"

describe "Rake::Pipeline Middleware" do
  include Rack::Test::Methods

  class StripAssertsFilter < Rake::Pipeline::Filter
    def generate_output(inputs, output)
      inputs.each do |input|
        output.write input.read.gsub(%r{^\s*assert\(.*\)\s*;?\s*$}m, '')
      end
    end
  end

  inputs = {
    "app/javascripts/jquery.js" => "var jQuery = {};\n",

    "app/javascripts/sproutcore.js" => <<-HERE.gsub(/^ {6}/, '')
      var SC = {};
      assert(SC);
      SC.hi = function() { console.log("hi"); };
    HERE
  }

  expected_output = <<-HERE.gsub(/^ {4}/, '')
    var jQuery = {};
    var SC = {};

    SC.hi = function() { console.log("hi"); };
  HERE

  app = middleware = pipeline = nil

  before do
    app = lambda { |env| [404, {}, ['not found']] }
    middleware = Rake::Pipeline::Middleware.new(app)

    inputs.each do |name, string|
      mkdir_p File.dirname(File.join(tmp, name))
      File.open(File.join(tmp, name), "w") { |file| file.write(string) }
    end

    pipeline = Rake::Pipeline.build do
      input tmp, "app/javascripts/*.js"
      filter(ConcatFilter) { "javascripts/application.js" }
      filter(StripAssertsFilter) { |input| input }
      output "public"
    end

    middleware.pipelines = [pipeline]

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
end
