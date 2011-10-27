require 'spec_helper'

describe Mongoid::Tree::Count do

  context 'without children' do
    let(:root) { CountNode.new(:name => 'root') }

    it 'should have a children_count equals to 0' do
      root.children_count.should eq 0
    end

    it 'should not have children' do
      root.has_children?.should be_false
    end
  end

  context 'with children' do
    let(:root) do
      root = CountNode.new(:name => 'root')
      child = CountNode.new(:name => 'child')
      root.children << child
      root.save
      root
    end

    it 'should have children' do
      root.has_children?.should be_true
    end

    it 'should have 1 children' do
      root.children_count.should eq 1
    end
  end
end
