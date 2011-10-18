module Rake
  class Pipeline
    class UnopenedFile < StandardError
    end

    # This class wraps a file for consumption inside of filters. It is
    # initialized with a root and path, and filters usually use the
    # `read` and `write` methods to work with these files.
    #
    # The `root` and `path` parameters are provided by the `Filter`
    # class' internal implementation. Individual filters do not need
    # to worry about them.
    #
    # The root of a FileWrapper is always an absolute path.
    class FileWrapper
      attr_accessor :root, :path, :encoding

      def initialize(root=nil, path=nil, encoding="UTF-8")
        @root, @path, @encoding = root, path, encoding
        @created_file = nil
      end

      # A FileWrapper is equal to another FileWrapper if they have the
      # same `root` and `path`
      def eql?(other)
        root == other.root && path == other.path
      end
      alias == eql?

      # Similarly, generate a FileWrapper's hash from its `root` and
      # `path`.
      def hash
        [root, path].hash
      end

      # The full path of a FileWrapper is its root joined with its path
      def fullpath
        raise "#{root}, #{path}" unless root =~ /^\//
        File.join(root, path)
      end

      def exists?
        File.exists?(fullpath)
      end

      def read
        contents = File.read(fullpath, :encoding => encoding)

        unless contents.valid_encoding?
          raise EncodingError, "The file at the path #{fullpath} is not valid UTF-8. Please save it again as UTF-8."
        end

        contents
      end

      def create
        FileUtils.mkdir_p(File.dirname(fullpath))
        @created_file = File.open(fullpath, "w:#{encoding}")

        if block_given?
          yield @created_file
        end

        @created_file
      ensure
        if block_given?
          @created_file.close
          @created_file = nil
        end
      end

      def close
        raise IOError, "closed stream" unless @created_file
        @created_file.close
        @created_file = nil
      end

      def closed?
        @created_file.nil?
      end

      def write(string)
        raise UnopenedFile unless @created_file
        @created_file.write(string)
      end

      def inspect
        "#<FileWrapper root=#{root.inspect} path=#{path.inspect}>"
      end

      alias to_s inspect
    end
  end
end
