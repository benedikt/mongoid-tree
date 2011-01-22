class Node
  include Mongoid::Document
  include Mongoid::Tree
  include Mongoid::Tree::Traversal

  field :name

  attr_accessible :name
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

  attr_accessible :name
end