# encoding: utf-8
module Mongoid
  module Tree
    ##
    # = Mongoid::Tree::Count
    #
    # Mongoid::Tree::Count provides a counter cache on children size.
    #
    # == Utility methods
    #
    # Check if a node has children
    #
    #   node.has_children?
    module Count
      extend ActiveSupport::Concern

      included do
        field :children_count, :type => Integer, :default => 0
        set_callback :create, :before, :update_children_count
      end

      module InstanceMethods

        def has_children?
          self.children_count > 0
        end

        private

        def update_children_count
          self.children_count = self.children.size
        end

      end
    end
  end
end
