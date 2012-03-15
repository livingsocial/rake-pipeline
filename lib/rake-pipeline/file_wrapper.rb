module Rake
  class Pipeline
    # This class wraps a file for consumption inside of filters. It is
    # initialized with a root and path, and filters usually use the
    # {#read} and {#write} methods to work with these files.
    #
    # The {#root} and +path+ parameters are provided by the {Filter}
    # class' internal implementation. Individual filters do not need
    # to worry about them.
    #
    # The root of a {FileWrapper} is always an absolute path.
    class FileWrapper
      # @return [String] an absolute path representing this {FileWrapper}'s
      #   root directory.
      attr_accessor :root

      # @return [String] the path to the file represented by the {FileWrapper},
      #   relative to its {#root}.
      attr_accessor :path

      # @return [String] the encoding that the file represented by this
      #   {FileWrapper} is encoded in. Filters set the {#encoding} to
      #   +BINARY+ if they are declared as processing binary data.
      attr_accessor :encoding

      # Create a new {FileWrapper}, passing in optional root, path, and
      # encoding. Any of the parameters can be ommitted and supplied later.
      #
      # @return [void]
      def initialize(root=nil, path=nil, encoding="UTF-8")
        @root, @path, @encoding = root, path, encoding
        @created_file = nil
      end

      # Create a new {FileWrapper FileWrapper} with the same root and
      # path as this {FileWrapper FileWrapper}, but with a specified
      # encoding.
      #
      # @param [String] encoding the encoding for the new object
      # @return [FileWrapper]
      def with_encoding(encoding)
        self.class.new(@root, @path, encoding)
      end

      # A {FileWrapper} is equal to another {FileWrapper} for hashing purposes
      # if they have the same {#root} and {#path}
      #
      # @param [FileWrapper] other another {FileWrapper} to compare.
      # @return [true,false]
      def eql?(other)
        return false unless other.is_a?(self.class)
        root == other.root && path == other.path
      end
      alias == eql?

      # Similar to {#eql?}, generate a {FileWrapper}'s {#hash} from its {#root}
      # and {#path}
      #
      # @see #eql?
      # @return [Fixnum] a hash code
      def hash
        [root, path].hash
      end

      # The full path of a FileWrapper is its root joined with its path
      #
      # @return [String] the {FileWrapper}'s full path
      def fullpath
        raise "#{root}, #{path}" unless root =~ /^(\/|[a-zA-Z]:[\\\/])/
        File.join(root, path)
      end

      # Make FileWrappers sortable
      #
      # @param [FileWrapper] other {FileWrapper FileWrapper}
      # @return [Fixnum] -1, 0, or 1
      def <=>(other)
        [root, path, encoding] <=> [other.root, other.path, other.encoding]
      end

      # Does the file represented by the {FileWrapper} exist in the file system?
      #
      # @return [true,false]
      def exists?
        File.exists?(fullpath)
      end

      # Read the contents of the file represented by the {FileWrapper}.
      #
      # Read the file using the {FileWrapper}'s encoding, which will result in
      # this method returning a +String+ tagged with the {FileWrapper}'s encoding.
      #
      # @return [String] the contents of the file
      # @raise [EncodingError] when the contents of the file are not valid in the
      #   expected encoding specified in {#encoding}.
      def read
        contents = if "".respond_to?(:encode)
          File.read(fullpath, :encoding => encoding)
        else
          File.read(fullpath)
        end

        if "".respond_to?(:encode) && !contents.valid_encoding?
          raise EncodingError, "The file at the path #{fullpath} is not valid UTF-8. Please save it again as UTF-8."
        end

        contents
      end

      # Create a new file at the {FileWrapper}'s {#fullpath}. If the file already
      # exists, it will be overwritten.
      #
      # @api private
      # @yieldparam [File] file the newly created file
      # @return [File] if a block was not given
      def create
        FileUtils.mkdir_p(File.dirname(fullpath))

        @created_file = if "".respond_to?(:encode)
          File.open(fullpath, "w:#{encoding}")
        else
          File.open(fullpath, "w")
        end

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

      # Close the file represented by the {FileWrapper} if it was previously opened.
      #
      # @api private
      # @return [void]
      def close
        raise IOError, "closed stream" unless @created_file
        @created_file.close
        @created_file = nil
      end

      # Check to see whether the file represented by the {FileWrapper} is open.
      #
      # @api private
      # @return [true,false]
      def closed?
        @created_file.nil?
      end

      # Write a String to a previously opened file. This method is called repeatedly
      # by a {Filter}'s +#generate_output+ method and does not create a brand new
      # file for each invocation.
      #
      # @raise [UnopenedFile] if the file is not already opened.
      def write(string)
        raise UnopenedFile unless @created_file
        @created_file.write(string)
      end

      # @return [String] A pretty representation of the {FileWrapper}.
      def inspect
        "#<FileWrapper root=#{root.inspect} path=#{path.inspect} encoding=#{encoding.inspect}>"
      end

      alias to_s inspect
    end
  end
end
