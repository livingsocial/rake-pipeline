module Rake
  class Pipeline
    class UnopenedFile < StandardError
    end

    class FileWrapper
      attr_accessor :root
      attr_accessor :path

      def fullpath
        File.join(root, path)
      end

      def exists?
        File.exists?(fullpath)
      end

      def read
        File.read(fullpath)
      end

      def create
        FileUtils.mkdir_p(File.dirname(fullpath))
        @created_file = File.open(fullpath, "w")
      end

      def close
        raise IOError, "closed stream" unless @created_file
        @created_file.close
        @created_file = nil
      end

      def write(string)
        raise UnopenedFile unless @created_file
        @created_file.write(string)
      end
    end
  end
end
