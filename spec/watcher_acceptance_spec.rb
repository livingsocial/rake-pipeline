require "rake-pipeline/middleware"
require "rake-pipeline/watcher"
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

  modified_assetfile_source = <<-HERE.gsub(/^ {4}/, '')
    require "#{tmp}/../support/spec_helpers/filters"
    output "public"

    input "#{tmp}", "app/**/*" do
      match "*.js" do
        concat { "javascripts/app.js" }
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
  let(:watcher) { Rake::Pipeline::Watcher.new(project) }

  before do
    Logger.any_instance.stub(:add)

    File.open(assetfile_path, "w") { |file| file.write(assetfile_source) }

    app = lambda { |env| [404, {}, ['not found']] }
    middleware = Rake::Pipeline::Middleware.new(app, assetfile_path)

    inputs.each do |name, string|
      path = File.join(tmp, name)
      if string
        mkdir_p File.dirname(path)
        File.open(path, "w") { |file| file.write(string) }
      else
        mkdir_p path
      end
    end

    watcher.start
    sleep 0.5
  end


  after do
    watcher.stop
  end


  it "updates the output when files change" do
    age_existing_files

    File.open(File.join(tmp, "app/javascripts/jquery.js"), "w") do |file|
      file.write "var jQuery = {};\njQuery.trim = function() {};\n"
    end
    sleep 0.5

    expected = <<-HERE.gsub(/^ {4}/, '')
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
    sleep 0.5

    expected = <<-HERE.gsub(/^ {4}/, '')
    var History = {};
    var jQuery = {};
    var SC = {};

    SC.hi = function() { console.log("hi"); };
    HERE

    get "/javascripts/application.js"

    last_response.body.should == expected
    last_response.headers["Content-Type"].should == "application/javascript"
  end

  it "recreates the pipeline when the Assetfile changes" do
    get "/javascripts/app.js"
    last_response.body.should == "not found"
    last_response.status.should == 404

    File.open(File.join(tmp, "Assetfile"), "w") do |file|
      file.write(modified_assetfile_source)
    end
    sleep 0.5

    expected = <<-HERE.gsub(/^ {4}/, '')
    var jQuery = {};
    var SC = {};

    SC.hi = function() { console.log("hi"); };
    HERE

    get "/javascripts/app.js"

    last_response.body.should == expected
    last_response.headers["Content-Type"].should == "application/javascript"
  end
end
