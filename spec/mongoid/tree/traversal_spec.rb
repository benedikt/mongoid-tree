require 'spec_helper'

describe Mongoid::Tree::Traversal do

  describe '#traverse' do

    subject { Node.new }

    it "should require a block" do
      expect { subject.traverse }.to raise_error(/No block given/)
    end

    [:depth_first].each do |method|
      it "should support #{method} traversal" do
        expect { subject.traverse(method) {} }.to_not raise_error
      end
    end

    it "should complain about unsupported traversal methods" do
      expect { subject.traverse('non_existing') {} }.to raise_error
    end

    it "should default to depth_first traversal" do
      subject.should_receive(:depth_first_traversal)
      subject.traverse {}
    end

  end

  describe 'depth first traversal' do

    it "should traverse correctly" do
      setup_tree <<-ENDTREE
        node1:
          - node2:
            - node3
          - node4:
            - node5
            - node6
          - node7
      ENDTREE

      result = []
      node(:node1).traverse(:depth_first) { |node| result << node }
      result.collect { |n| n.name.to_sym }.should == [:node1, :node2, :node3, :node4, :node5, :node6, :node7]
    end

    it "should traverse correctly on merged trees" do

      setup_tree <<-ENDTREE
        - node4:
          - node5
          - node6:
            - node7

        - node1:
          - node2:
            - node3
      ENDTREE


      node(:node1).children << node(:node4)


      result = []
      node(:node1).traverse(:depth_first) { |node| result << node }
      result.collect { |n| n.name.to_sym }.should == [:node1, :node2, :node3, :node4, :node5, :node6, :node7]
    end

    describe 'with reordered nodes' do
      before do
        setup_ordered_tree <<-ENDTREE
          node1:
            - node2:
              - node3
            - node4:
              - node6
              - node5
            - node7
        ENDTREE
        node(:node5).move_above(node(:node6))
      end

      it 'should return the nodes in the correct order' do
        result = []
        node(:node1).traverse(:depth_first) { |node| result << node }
        result.collect { |n| n.name.to_sym }.should == [:node1, :node2, :node3, :node4, :node5, :node6, :node7]
      end

    end

  end

  describe 'breadth first traversal' do

    it "should traverse correctly" do
      tree = setup_tree <<-ENDTREE
        node1:
          - node2:
            - node5
          - node3:
            - node6
            - node7
          - node4
      ENDTREE

      result = []
      node(:node1).traverse(:breadth_first) { |n| result << n }
      result.collect { |n| n.name.to_sym }.should == [:node1, :node2, :node3, :node4, :node5, :node6, :node7]
    end

  end

end
