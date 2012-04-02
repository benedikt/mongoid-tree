module Mongoid
  module Tree
    ##
    # = Mongoid::Tree::Traversal
    #
    # Mongoid::Tree::Traversal provides a #traverse method to walk through the tree.
    # It supports these traversal methods:
    #
    # * depth_first
    # * breadth_first
    #
    # == Depth First Traversal
    #
    # See http://en.wikipedia.org/wiki/Depth-first_search for a proper description.
    #
    # Given a tree like:
    #
    #   node1:
    #    - node2:
    #      - node3
    #    - node4:
    #      - node5
    #      - node6
    #    - node7
    #
    # Traversing the tree using depth first traversal would visit each node in this order:
    #
    #   node1, node2, node3, node4, node5, node6, node7
    #
    # == Breadth First Traversal
    #
    # See http://en.wikipedia.org/wiki/Breadth-first_search for a proper description.
    #
    # Given a tree like:
    #
    #   node1:
    #     - node2:
    #       - node5
    #     - node3:
    #       - node6
    #       - node7
    #     - node4
    #
    # Traversing the tree using breadth first traversal would visit each node in this order:
    #
    #   node1, node2, node3, node4, node5, node6, node7
    #
    module Traversal
      extend ActiveSupport::Concern


      ##
      # This module implements class methods that will be available 
      # on the document that includes Mongoid::Tree::Traversal
      module ClassMethods
        ##
        # Traverses the entire tree, one root at a time, using the given traversal
        # method (Default is :depth_first).
        # 
        # See Mongoid::Tree::Traversal for available traversal methods.
        #
        # @example
        #
        #   # Say we have the following tree, and want to print its hierarchy:
        #   #   root_1
        #   #     child_1_a
        #   #   root_2
        #   #     child_2_a
        #   #       child_2_a_1
        #
        #   Node.traverse(:depth_first) do |node|
        #     indentation = '  ' * node.depth
        #
        #     puts "#{indentation}#{node.name}"
        #   end
        #
        def traverse(type = :depth_first, &block)
          roots.collect { |root| root.traverse(type, &block) }.flatten
        end
      end

      ##
      # Traverses the tree using the given traversal method (Default is :depth_first)
      # and passes each document node to the block.
      #
      # See Mongoid::Tree::Traversal for available traversal methods.
      #
      # @example
      #
      #   results = []
      #   root.traverse(:depth_first) do |node|
      #     results << node
      #   end
      #
      #   root.traverse(:depth_first).map(&:name)
      #   root.traverse(:depth_first, &:name)
      #
      def traverse(type = :depth_first, &block)
        block ||= lambda { |node| node }
        send("#{type}_traversal", &block)
      end

      private

      def depth_first_traversal(&block)
        result = [block.call(self)] + self.children.collect { |c| c.send(:depth_first_traversal, &block) }
        result.flatten
      end

      def breadth_first_traversal(&block)
        result = []
        queue = [self]
        while queue.any? do
          node = queue.shift
          result << block.call(node)
          queue += node.children
        end
        result
      end
    end
  end
end
