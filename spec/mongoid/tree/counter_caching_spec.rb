require 'spec_helper'

describe Mongoid::Tree::CounterCaching do

  subject { CounterCachedNode }

  before do
    setup_tree <<-ENDTREE
      node1:
        - node2:
          - node3
        - node4:
          - node5
          - node6
        - node7
    ENDTREE
  end

  context 'when a child gets created' do
    it 'should calculate the counter cache' do
      expect(node(:node1).children_count).to eq(3)
    end
  end

  context 'when a child gets destroyed' do
    it 'should update the counter cache' do
      node(:node4).destroy
      expect(node(:node1).children_count).to eq(2)
    end
  end

  context 'when a child gets moved' do
    it 'should update the counter cache' do
      node(:node6).update(parent: node(:node1))
      expect(node(:node4).children_count).to eq(1)
      expect(node(:node1).children_count).to eq(4)
    end
  end
end
