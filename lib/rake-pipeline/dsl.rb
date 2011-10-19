
module Rake
  class Pipeline
    class DSL
      attr_reader :pipeline

      def self.evaluate(pipeline, &block)
        new(pipeline).instance_eval(&block)
      end

      def initialize(pipeline)
        @pipeline = pipeline
      end

      def input(root, files=nil)
        pipeline.input_root = root
        pipeline.input_glob = files
      end

      def filter(filter_class, string=nil, &block)
        block ||= if string
          proc { string }
        else
          proc { |input| input }
        end

        filter = filter_class.new
        filter.output_name = block
        pipeline.add_filter(filter)
      end

      def output(root)
        pipeline.output_root = root
      end

      def tmpdir(root)
        pipeline.tmpdir = root
      end

      def rake_application(app)
        pipeline.rake_application = app
      end

      def files(glob, &block)
        block ||= proc { filter Rake::Pipeline::ConcatFilter }
        new_pipeline = pipeline.build(&block)
        new_pipeline.input_glob = glob
      end

      alias file files
    end
  end
end


