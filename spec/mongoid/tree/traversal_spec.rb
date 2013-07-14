require 'spec_helper'

describe Mongoid::Tree::Traversal do

  subject { OrderedNode }

  describe '#traverse' do

    subject { Node.new }

    [:depth_first, :breadth_first].each do |method|
      it "should support #{method} traversal" do
        expect { subject.traverse(method) {} }.to_not raise_error
      end
    end

    it "should complain about unsupported traversal methods" do
      expect { subject.traverse('non_existing') {} }.to raise_error
    end

    it "should default to depth_first traversal" do
      expect(subject).to receive(:depth_first_traversal)
      subject.traverse {}
    end
  end

  describe 'depth first traversal' do

    describe 'with unmodified tree' do
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

      it "should traverse correctly" do
        result = []
        node(:node1).traverse(:depth_first) { |node| result << node }
        expect(result.collect { |n| n.name.to_sym }).to eq([:node1, :node2, :node3, :node4, :node5, :node6, :node7])
      end

      it "should return and array containing the results of the block for each node" do
        result = node(:node1).traverse(:depth_first) { |n| n.name.to_sym }
        expect(result).to eq([:node1, :node2, :node3, :node4, :node5, :node6, :node7])
      end
    end

    describe 'with merged trees' do
      before do
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
      end

      it "should traverse correctly" do
        result = node(:node1).traverse(:depth_first) { |n| n.name.to_sym }
        expect(result).to eq([:node1, :node2, :node3, :node4, :node5, :node6, :node7])
      end
    end

    describe 'with reordered nodes' do

      before do
        setup_tree <<-ENDTREE
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

      it 'should iterate through the nodes in the correct order' do
        result = []
        node(:node1).traverse(:depth_first) { |node| result << node }
        expect(result.collect { |n| n.name.to_sym }).to eq([:node1, :node2, :node3, :node4, :node5, :node6, :node7])
      end

      it 'should return the nodes in the correct order' do
        result = node(:node1).traverse(:depth_first)
        expect(result.collect { |n| n.name.to_sym }).to eq([:node1, :node2, :node3, :node4, :node5, :node6, :node7])
      end

    end

  end

  describe 'breadth first traversal' do

    before do
      setup_tree <<-ENDTREE
        node1:
          - node2:
            - node5
          - node3:
            - node6
            - node7
          - node4
      ENDTREE
    end

    it "should traverse correctly" do
      result = []
      node(:node1).traverse(:breadth_first) { |n| result << n }
      expect(result.collect { |n| n.name.to_sym }).to eq([:node1, :node2, :node3, :node4, :node5, :node6, :node7])
    end

    it "should return and array containing the results of the block for each node" do
      result = node(:node1).traverse(:breadth_first) { |n| n.name.to_sym }
      expect(result).to eq([:node1, :node2, :node3, :node4, :node5, :node6, :node7])
    end

  end

  describe '.traverse' do
    before :each do
      setup_tree <<-ENDTREE
        - root1
        - root2
      ENDTREE

      @root1 = node(:root1)
      @root2 = node(:root2)

      Node.stub(:roots).and_return [@root1, @root2]
    end

    it 'should grab each root' do
      expect(Node).to receive(:roots).and_return []

      expect(Node.traverse).to eq([])
    end

    it 'should default the "type" arg to :depth_first' do
      expect(@root1).to receive(:traverse).with(:depth_first).and_return([])
      expect(@root2).to receive(:traverse).with(:depth_first).and_return([])

      expect(Node.traverse).to eq([])
    end

    it 'should traverse each root' do
      expect(@root1).to receive(:traverse).and_return([1, 2])
      expect(@root2).to receive(:traverse).and_return([3, 4])

      expect(Node.traverse).to eq([1, 2, 3, 4])
    end

    describe 'when the "type" arg is :breadth_first' do

      it 'should traverse breadth-first' do
        expect(@root1).to receive(:traverse).with(:breadth_first).and_return([])
        expect(@root2).to receive(:traverse).with(:breadth_first).and_return([])

        Node.traverse :breadth_first
      end
    end
  end
end
