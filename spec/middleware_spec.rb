require "rake-pipeline/middleware"
require "rake-pipeline/filters"
require "rack/test"

describe "Rake::Pipeline Middleware" do
  include Rack::Test::Methods

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

  assetfile_source = <<-HERE.gsub(/^ {4}/, '')
    require "#{tmp}/../support/spec_helpers/filters"
    output "public"

    map "/dynamic-request.js" do
      [200, { "Content-Type" => "text/plain" }, ["I am dynamic!"]]
    end

    input "#{tmp}", "app/**/*" do
      match "*.js" do
        concat "javascripts/application.js"
        filter(Rake::Pipeline::SpecHelpers::Filters::StripAssertsFilter) { |input| input }
      end

      # copy the rest
      concat { |input| input.sub(%r|^app/|, '') }
    end
  HERE

  app = middleware = nil

  let(:app) { middleware }
  let(:assetfile_path) {  File.join(tmp, "Assetfile") }
  let(:project) { Rake::Pipeline::Project.new(assetfile_path) }

  before do
    File.open(assetfile_path, "w") { |file| file.write(assetfile_source) }

    app = lambda { |env| [404, {}, ['not found']] }
    middleware = Rake::Pipeline::Middleware.new(app, assetfile_path)
  end

  describe "dynamic requests" do
    it "returns the value from the given block for paths that have been mapped" do
      project.invoke_clean
      get "/dynamic-request.js"

      last_response.should be_ok
      last_response.headers["Content-Type"].should == "text/plain"
      last_response.body.should == "I am dynamic!"
    end
  end

  describe "static requests" do
    before do
      inputs.each do |name, string|
        path = File.join(tmp, name)
        if string
          mkdir_p File.dirname(path)
          File.open(path, "w") { |file| file.write(string) }
        else
          mkdir_p path
        end
      end

      project.invoke_clean
      get "/javascripts/application.js"
    end

    it "returns files relative to the output directory" do
      last_response.should be_ok

      last_response.body.should == expected_output
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
end
