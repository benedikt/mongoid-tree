module Mongoid
  module Tree
    ##
    # = Mongoid::Tree::CounterCaching
    #
    # Mongoid::Tree doesn't use a counter cache for the children by default.
    # To enable counter caching for each node's children, include
    # both Mongoid::Tree and Mongoid::Tree::CounterCaching into your document.
    module CounterCaching
      extend ActiveSupport::Concern

      included do
        field :children_count, :type => Integer, :default => 0

        metadata = relations['parent']
        metadata.options[:counter_cache] = true

        if respond_to?(:add_counter_cache_callbacks)
          add_counter_cache_callbacks(metadata)
        else
          metadata.send(:define_counter_cache_callbacks!)
        end
      end
    end
  end
end
