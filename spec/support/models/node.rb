class Node
  include Mongoid::Document
  include Mongoid::Tree

  field :name
end

class SubclassedNode < Node
end

