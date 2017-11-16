class Node
  include Mongoid::Document
  include Mongoid::Tree
  include Mongoid::Tree::Traversal

  field :name
end

class SubclassedNode < Node
end

# Adding ordering on subclasses currently doesn't work as expected.
#
# class OrderedNode < Node
#   include Mongoid::Tree::Ordering
# end
class OrderedNode
  include Mongoid::Document
  include Mongoid::Tree
  include Mongoid::Tree::Traversal
  include Mongoid::Tree::Ordering

  field :name
end

class NodeWithEmbeddedDocument < Node
  embeds_one :embedded_document, :cascade_callbacks => true
end

class EmbeddedDocument
  include Mongoid::Document
end

class CounterCachedNode < Node
  include Mongoid::Tree::CounterCaching
end
