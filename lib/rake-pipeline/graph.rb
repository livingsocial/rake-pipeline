require "set"

module Rake
  class Pipeline
    # The goal of this class is to make is easy to implement dynamic
    # dependencies in additional_dependencies without having to parse
    # all the files all of the time.
    #
    # To illustrate, imagine that we have two source files with the
    # following inline dependencies:
    #
    # * application.scss
    #   * _core.scss
    # * admin.scss
    #   * _admin.scss
    #
    # And further imagine that `_admin.scss` has an inline dependency
    # on `_core.scss`.
    #
    # On initial build, we will scan all of the source files, find
    # the dependencies, and build a node for each file, annotating
    # the source files with `:source => true`. We also store off the
    # `mtime` of each file in its node. We link each file to its
    # dependencies.
    #
    # The `additional_dependencies` are a map of the files to their
    # children, which will be used when generating rake tasks.
    #
    # Later, let's say that we change `_admin.scss`. We will need
    # to unlink its dependencies first (on `_core.scss`), rescan
    # the file, and create nodes for its dependencies. If no new
    # dependencies

    class Graph
      class MissingNode < StandardError
      end

      class Node
        # @return [String] the identifier of the node
        attr_reader :name

        # @return [Set] a Set of parent nodes
        attr_reader :parents

        # @return [Set] a Set of child nodes
        attr_reader :children

        # @return [Hash] a Hash of metadata
        attr_reader :metadata

        # @param [String] name the identifier of the node
        # @param [Hash] metadata an optional hash of metadata
        def initialize(name, metadata={})
          @name = name
          @parents = Set.new
          @children = Set.new
          @metadata = metadata
        end

        # A node is equal another node if it has the same name.
        # This is because the Graph ensures that only one node
        # with a given name can be created.
        #
        # @param [Node] other the node to compare
        def ==(other)
          @name == other.name
        end
      end

      def initialize
        @map = {}
      end

      # @return [Array] an Array of all of the nodes in the graph
      def nodes
        @map.values
      end

      # Add a new node to the graph. If an existing node with the
      # current name already exists, do not add the node.
      #
      # @param [String] name an identifier for the node.
      # @param [Hash] metadata optional metadata for the node
      def add(name, metadata={})
        return if @map.include?(name)
        @map[name] = Node.new(name, metadata)
      end

      # Remove a node from the graph. Unlink its parent and children
      # from it.
      #
      # If the existing node does not exist, raise.
      #
      # @param [String] name an identifier for the node
      def remove(name)
        node = verify(name)

        node.parents.each do |parent_node|
          parent_node.children.delete node
        end

        node.children.each do |child_node|
          child_node.parents.delete node
        end

        @map.delete(name)
      end

      # Add a link from the parent to the child. This link is a
      # two-way link, so the child will be added to the parent's
      # `children` and the parent will be added to the child's
      # `parents`.
      #
      # The parent and child are referenced by node identifier.
      #
      # @param [String] parent the identifier of the parent
      # @param [String] child the identifier of the child
      def link(parent, child)
        parent, child = lookup(parent, child)

        parent.children << child
        child.parents << parent
      end

      # Remove a link from the parent to the child.
      #
      # The parent and child are referenced by node identifier.
      #
      # @param [String] parent the identifier of the parent
      # @param [String] child the identifier of the child
      def unlink(parent, child)
        parent, child = lookup(parent, child)

        parent.children.delete(child)
        child.parents.delete(parent)
      end

      # Look up a node by name
      #
      # @param [String] name the identifier of the node
      # @return [Node] the node referenced by the specified identifier
      def [](name)
        @map[name]
      end

    private
      # Verify that the parent and child nodes exist, and return
      # the nodes with the specified identifiers.
      #
      # The parent and child are referenced by node identifier.
      #
      # @param [String] parent the identifier of the parent
      # @param [String] child the identifier of the child
      # @return [Array(Node, Node)] the parent and child nodes
      def lookup(parent, child)
        parent = verify(parent)
        child = verify(child)

        return parent, child
      end

      # Verify that a node with a given identifier exists, and
      # if it does, return it.
      #
      # If it does not, raise an exception.
      #
      # @param [String] name the identifier of the node
      # @raise [MissingNode] if a node with the given name is
      #   not found, raise.
      # @return [Node] the n
      def verify(name)
        node = @map[name]
        raise MissingNode, "Node #{name} does not exist" unless node
        node
      end
    end
  end
end
