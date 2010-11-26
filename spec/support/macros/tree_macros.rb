require 'yaml'

module Mongoid::Tree::TreeMacros

  def setup_tree(tree)
    create_tree(YAML.load(tree))
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
  def create_tree(object)
    case object
      when String then return create_node(object)
      when Array then object.each { |tree| create_tree(tree) }
      when Hash then
        name, children = object.first
        node = create_node(name)
        children.each { |c| node.children << create_tree(c) }
        return node
    end
  end

  def create_node(name)
    @nodes ||= HashWithIndifferentAccess.new
    @nodes[name] = subject.create(:name => name)
  end
end

RSpec.configure do |config|
  config.include Mongoid::Tree::TreeMacros
end
