require 'yaml'

module Mongoid::Tree::TreeMacros

  def setup_tree(tree)
    create_tree(YAML.load(tree), {:ordered => false})
  end

  def setup_ordered_tree(tree)
    create_tree(YAML.load(tree), {:ordered => true})
  end

  def node(name)
    @nodes[name].reload
  end

  def print_tree(node, inspect = false, depth = 0)
    print '  ' * depth
    print '- ' unless depth == 0
    print node.name
    print " (#{node.inspect})" if inspect
    print ':' if node.children.any?
    print "\n"
    node.children.each { |c| print_tree(c, inspect, depth + 1) }
  end

private
  def create_tree(object, opts={})
    case object
      when String: return create_node(object, opts)
      when Array: object.each { |tree| create_tree(tree, opts) }
      when Hash:
        name, children = object.first
        node = create_node(name, opts)
        children.each { |c| node.children << create_tree(c, opts) }
        return node
    end
  end

  def create_node(name, opts={})
    node_class = opts[:ordered] ? OrderedNode : Node
    @nodes ||= HashWithIndifferentAccess.new
    @nodes[name] = node_class.create(:name => name)
  end
end

RSpec.configure do |config|
  config.include Mongoid::Tree::TreeMacros
end
