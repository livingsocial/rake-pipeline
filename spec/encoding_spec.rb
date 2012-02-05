# encoding: UTF-8

if "".respond_to?(:encode)
  class String
    def strip_heredoc
      indent = scan(/^[ \t]*(?=\S)/).min
      indent = indent ? indent.size : 0
      gsub(/^[ \t]{#{indent}}/, '')
    end
  end

  inputs = {
    "app/javascripts/jquery.js" => <<-HERE.strip_heredoc,
      var jQuery = { japanese: "こんにちは" };
    HERE

    "app/javascripts/sproutcore.js" => <<-HERE.strip_heredoc,
      var SC = {};
      assert(SC);
      SC.hi = function() { console.log("こんにちは"); };
    HERE
  }

  expected_output = <<-HERE.strip_heredoc
    var jQuery = { japanese: "こんにちは" };
    var SC = {};

    SC.hi = function() { console.log("こんにちは"); };
  HERE

  describe "the pipeline's encoding handling" do
    Filters = Rake::Pipeline::SpecHelpers::Filters

    let(:inputs) { inputs }

    def output_should_exist(expected, encoding="UTF-8")
      output = File.join(tmp, "public/javascripts/application.js")

      File.exists?(output).should be_true
      output = File.read(output, :encoding => encoding)
      output.should == expected
      output.should be_valid_encoding
    end

    def create_files
      inputs.each do |name, contents|
        filename = File.join(tmp, name)
        mkdir_p File.dirname(filename)

        File.open(filename, "w:#{encoding}") do |file|
          file.write contents.encode(encoding)
        end
      end
    end

    before do
      create_files

      @pipeline = Rake::Pipeline.build do
        output "public"
        input "#{tmp}/app/javascripts/", "*.js"
        concat "javascripts/application.js"
        filter Filters::StripAssertsFilter
      end
    end

    describe "when the input is UTF-8" do
      let(:encoding) { "UTF-8" }

      it "creates the correct file" do
        @pipeline.invoke
        output_should_exist(expected_output)
      end
    end

    describe "when the input is not UTF-8" do
      let(:encoding) { "EUC-JP" }

      it "raises an exception" do
        lambda { @pipeline.invoke }.should raise_error(Rake::Pipeline::EncodingError, /not valid UTF-8/)
      end
    end

    describe "when dealing with only BINARY-type filters" do
      let(:encoding) { "EUC-JP" }

      it "does not raise an exception" do
         pipeline = Rake::Pipeline.build do
          output "public"
          input "#{tmp}/app/javascripts/", "*.js"
          concat "javascripts/application.js"
        end

        pipeline.invoke

        expected = inputs.map do |filename, contents|
          contents.encode("EUC-JP")
        end.join

        output_should_exist(expected.force_encoding("BINARY"), "BINARY")
      end
    end
  end
end
