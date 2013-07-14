require 'spec_helper'

describe Mongoid::Tree::Ordering do

  subject { OrderedNode }

  it "should store position as an Integer with a default of nil" do
    f = OrderedNode.fields['position']
    expect(f).not_to be_nil
    expect(f.options[:type]).to eq(Integer)
    expect(f.options[:default]).not_to be
  end

  describe 'when saved' do
    before(:each) do
      setup_tree <<-ENDTREE
        - root:
          - child:
            - subchild:
              - subsubchild
        - other_root:
          - other_child
          - another_child
      ENDTREE
    end

    it "should assign a default position of 0 to each node without a sibling" do
      expect(node(:child).position).to eq(0)
      expect(node(:subchild).position).to eq(0)
      expect(node(:subsubchild).position).to eq(0)
    end

    it "should place siblings at the end of the list by default" do
      expect(node(:root).position).to eq(0)
      expect(node(:other_root).position).to eq(1)
      expect(node(:other_child).position).to eq(0)
      expect(node(:another_child).position).to eq(1)
    end

    it "should move a node to the end of a list when it is moved to a new parent" do
      other_root = node(:other_root)
      child = node(:child)
      expect(child.position).to eq(0)
      other_root.children << child
      child.reload
      expect(child.position).to eq(2)
    end

    it "should correctly reposition siblings when one of them is removed" do
      node(:other_child).destroy
      expect(node(:another_child).position).to eq(0)
    end

    it "should correctly reposition siblings when one of them is added to another parent" do
      node(:root).children << node(:other_child)
      expect(node(:another_child).position).to eq(0)
    end

    it "should correctly reposition siblings when the parent is changed" do
      other_child = node(:other_child)
      other_child.parent = node(:root)
      other_child.save!
      expect(node(:another_child).position).to eq(0)
    end

    it "should not reposition siblings when it's not yet saved" do
      new_node = OrderedNode.new(:name => 'new')
      new_node.parent = node(:root)
      expect(new_node).not_to receive(:reposition_former_siblings)
      new_node.save
    end
  end

  describe 'destroy strategies' do
    before(:each) do
      setup_tree <<-ENDTREE
        - root:
          - child:
            - subchild
          - other_child
        - other_root
      ENDTREE
    end

    describe ':move_children_to_parent' do
      it "should set its childen's parent_id to the documents parent_id" do
        node(:child).move_children_to_parent
        expect(node(:child)).to be_leaf
        expect(node(:root).children.to_a).to eq([node(:child), node(:other_child), node(:subchild)])
      end
    end
  end

  describe 'utility methods' do
    before(:each) do
      setup_tree <<-ENDTREE
        - first_root:
          - first_child_of_first_root
          - second_child_of_first_root
        - second_root
        - third_root
      ENDTREE
    end

    describe '#lower_siblings' do
      it "should return a collection of siblings lower on the list" do
        node(:second_child_of_first_root).reload
        expect(node(:first_root).lower_siblings.to_a).to eq([node(:second_root), node(:third_root)])
        expect(node(:second_root).lower_siblings.to_a).to eq([node(:third_root)])
        expect(node(:third_root).lower_siblings.to_a).to eq([])
        expect(node(:first_child_of_first_root).lower_siblings.to_a).to eq([node(:second_child_of_first_root)])
        expect(node(:second_child_of_first_root).lower_siblings.to_a).to eq([])
      end
    end

    describe '#higher_siblings' do
      it "should return a collection of siblings lower on the list" do
        expect(node(:first_root).higher_siblings.to_a).to eq([])
        expect(node(:second_root).higher_siblings.to_a).to eq([node(:first_root)])
        expect(node(:third_root).higher_siblings.to_a).to eq([node(:first_root), node(:second_root)])
        expect(node(:first_child_of_first_root).higher_siblings.to_a).to eq([])
        expect(node(:second_child_of_first_root).higher_siblings.to_a).to eq([node(:first_child_of_first_root)])
      end
    end

    describe '#at_top?' do
      it "should return true when the node is first in the list" do
        expect(node(:first_root)).to be_at_top
        expect(node(:first_child_of_first_root)).to be_at_top
      end

      it "should return false when the node is not first in the list" do
        expect(node(:second_root)).not_to be_at_top
        expect(node(:third_root)).not_to be_at_top
        expect(node(:second_child_of_first_root)).not_to be_at_top
      end
    end

    describe '#at_bottom?' do
      it "should return true when the node is last in the list" do
        expect(node(:third_root)).to be_at_bottom
        expect(node(:second_child_of_first_root)).to be_at_bottom
      end

      it "should return false when the node is not last in the list" do
        expect(node(:first_root)).not_to be_at_bottom
        expect(node(:second_root)).not_to be_at_bottom
        expect(node(:first_child_of_first_root)).not_to be_at_bottom
      end
    end

    describe '#last_sibling_in_list' do
      it "should return the last sibling in the list containing the current sibling" do
        expect(node(:first_root).last_sibling_in_list).to eq(node(:third_root))
        expect(node(:second_root).last_sibling_in_list).to eq(node(:third_root))
        expect(node(:third_root).last_sibling_in_list).to eq(node(:third_root))
      end
    end

    describe '#first_sibling_in_list' do
      it "should return the first sibling in the list containing the current sibling" do
        expect(node(:first_root).first_sibling_in_list).to eq(node(:first_root))
        expect(node(:second_root).first_sibling_in_list).to eq(node(:first_root))
        expect(node(:third_root).first_sibling_in_list).to eq(node(:first_root))
      end
    end

    describe '#ancestors' do
      it "should be returned in the correct order" do
        setup_tree <<-ENDTREE
          - root:
            - level_1_a
            - level_1_b:
              - level_2_a:
                - leaf
        ENDTREE

        expect(node(:leaf).ancestors.to_a).to eq([node(:root), node(:level_1_b), node(:level_2_a)])
      end

      it "should return the ancestors in correct order even after rearranging" do
        setup_tree <<-ENDTREE
          - root:
            - child:
              - subchild
        ENDTREE

        child = node(:child); child.parent = nil; child.save!
        root = node(:root); root.parent = node(:child); root.save!
        subchild = node(:subchild); subchild.parent = root; subchild.save!

        expect(subchild.ancestors.to_a).to eq([child, root])
      end
    end
  end

  describe 'moving nodes around' do
    before(:each) do
      setup_tree <<-ENDTREE
        - first_root:
          - first_child_of_first_root
          - second_child_of_first_root
        - second_root:
          - first_child_of_second_root
        - third_root:
          - first
          - second
          - third
      ENDTREE
    end

    describe '#move_below' do
      it 'should fix positions within the current list when moving an sibling away from its current parent' do
        node_to_move = node(:first_child_of_first_root)
        node_to_move.move_below(node(:first_child_of_second_root))
        expect(node(:second_child_of_first_root).position).to eq(0)
      end

      it 'should work when moving to a different parent' do
        node_to_move = node(:first_child_of_first_root)
        new_parent = node(:second_root)
        node_to_move.move_below(node(:first_child_of_second_root))
        node_to_move.reload
        expect(node_to_move).to be_at_bottom
        expect(node(:first_child_of_second_root)).to be_at_top
      end

      it 'should be able to move the first node below the second node' do
        first_node = node(:first_root)
        second_node = node(:second_root)
        first_node.move_below(second_node)
        first_node.reload
        second_node.reload
        expect(second_node).to be_at_top
        expect(first_node.higher_siblings.to_a).to eq([second_node])
      end

      it 'should be able to move the last node below the first node' do
        first_node = node(:first_root)
        last_node = node(:third_root)
        last_node.move_below(first_node)
        first_node.reload
        last_node.reload
        expect(last_node).not_to be_at_bottom
        expect(node(:second_root)).to be_at_bottom
        expect(last_node.higher_siblings.to_a).to eq([first_node])
      end
    end

    describe '#move_above' do
      it 'should fix positions within the current list when moving an sibling away from its current parent' do
        node_to_move = node(:first_child_of_first_root)
        node_to_move.move_above(node(:first_child_of_second_root))
        expect(node(:second_child_of_first_root).position).to eq(0)
      end

      it 'should work when moving to a different parent' do
        node_to_move = node(:first_child_of_first_root)
        new_parent = node(:second_root)
        node_to_move.move_above(node(:first_child_of_second_root))
        node_to_move.reload
        expect(node_to_move).to be_at_top
        expect(node(:first_child_of_second_root)).to be_at_bottom
      end

      it 'should be able to move the last node above the second node' do
        last_node = node(:third_root)
        second_node = node(:second_root)
        last_node.move_above(second_node)
        last_node.reload
        second_node.reload
        expect(second_node).to be_at_bottom
        expect(last_node.higher_siblings.to_a).to eq([node(:first_root)])
      end

      it 'should be able to move the first node above the last node' do
        first_node = node(:first_root)
        last_node = node(:third_root)
        first_node.move_above(last_node)
        first_node.reload
        last_node.reload
        expect(node(:second_root)).to be_at_top
        expect(first_node.higher_siblings.to_a).to eq([node(:second_root)])
      end
    end

    describe "#move_to_top" do
      it "should return true when attempting to move the first sibling" do
        expect(node(:first_root).move_to_top).to eq(true)
        expect(node(:first_child_of_first_root).move_to_top).to eq(true)
      end

      it "should be able to move the last sibling to the top" do
        first_node = node(:first_root)
        last_node = node(:third_root)
        last_node.move_to_top
        first_node.reload
        expect(last_node).to be_at_top
        expect(first_node).not_to be_at_top
        expect(first_node.higher_siblings.to_a).to eq([last_node])
        expect(last_node.lower_siblings.to_a).to eq([first_node, node(:second_root)])
      end
    end

    describe "#move_to_bottom" do
      it "should return true when attempting to move the last sibling" do
        expect(node(:third_root).move_to_bottom).to eq(true)
        expect(node(:second_child_of_first_root).move_to_bottom).to eq(true)
      end

      it "should be able to move the first sibling to the bottom" do
        first_node = node(:first_root)
        middle_node = node(:second_root)
        last_node = node(:third_root)
        first_node.move_to_bottom
        middle_node.reload
        last_node.reload
        expect(first_node).not_to be_at_top
        expect(first_node).to be_at_bottom
        expect(last_node).not_to be_at_bottom
        expect(last_node).not_to be_at_top
        expect(middle_node).to be_at_top
        expect(first_node.lower_siblings.to_a).to eq([])
        expect(last_node.higher_siblings.to_a).to eq([middle_node])
      end
    end

    describe "#move_up" do
      it "should correctly move nodes up" do
        node(:third).move_up
        expect(node(:third_root).children).to eq([node(:first), node(:third), node(:second)])
      end
    end

    describe "#move_down" do
      it "should correctly move nodes down" do
        node(:first).move_down
        expect(node(:third_root).children).to eq([node(:second), node(:first), node(:third)])
      end
    end
  end # moving nodes around
end # Mongoid::Tree::Ordering
