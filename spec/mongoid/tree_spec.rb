require 'spec_helper'

describe Mongoid::Tree do

  it "should reference many children as inverse of parent with index" do
    a = Node.associations['children']
    a.should_not be_nil
    a.association.should == Mongoid::Associations::ReferencesMany
    a.options.class_name.should == 'Node'
    a.options.foreign_key.should == 'parent_id'
    Node.index_options.should have_key('parent_id')
  end

  it "should be referenced in one parent as inverse of children" do
    a = Node.associations['parent']
    a.should_not be_nil
    a.association.should == Mongoid::Associations::ReferencedIn
    a.options.class_name.should == 'Node'
    a.options.inverse_of.should == :children
    a.options.index.should be_true
  end

  it "should store parent_ids as Array with [] as default with index" do
    f = Node.fields['parent_ids']
    f.should_not be_nil
    f.options[:type].should == Array
    f.options[:default].should == []
    Node.index_options.should have_key(:parent_ids)
  end

  it "should store position as an Integer with a default of nil" do
    f = Node.fields['position']
    f.should_not be_nil
    f.options[:type].should == Integer
    f.options[:default].should == nil
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
      ENDTREE
    end

    it "should set the child's parent_id when added to parent's children" do
      root = Node.create; child = Node.create
      root.children << child
      child.parent.should == root
      child.parent_id.should == root.id
    end

    it "should set the child's parent_id parent is set on child" do
      root = Node.create; child = Node.create
      child.parent = root
      child.parent.should == root
      child.parent_id.should == root.id
    end

    it "should rebuild its parent_ids" do
      root = Node.create; child = Node.create
      root.children << child
      child.parent_ids.should == [root.id]
    end

    it "should rebuild its children's parent_ids when its own parent_ids changed" do
      other_root = node(:other_root); child = node(:child); subchild = node(:subchild);
      other_root.children << child
      subchild.reload # To get the updated version
      subchild.parent_ids.should == [other_root.id, child.id]
    end

    it "should correctly rebuild its descendants' parent_ids when moved into an other subtree" do
      subchild = node(:subchild); subsubchild = node(:subsubchild); other_child = node(:other_child)
      other_child.children << subchild
      subsubchild.reload
      subsubchild.parent_ids.should == [node(:other_root).id, other_child.id, subchild.id]
    end

    it "should rebuild its children's parent_ids when its own parent_id is removed" do
      node(:child).update_attributes(:parent_id => nil)
      node(:subchild).parent_ids.should == [node(:child).id]
    end

    it "should not rebuild its children's parent_ids when it's not required" do
      root = node(:root)
      root.should_not_receive(:rearrange_children)
      root.save
    end

    it "should prevent cycles" do
      child = node(:child)
      child.parent = node(:subchild)
      child.should_not be_valid
      child.errors[:parent_id].should_not be_nil
    end

    it "should assign a default position of 0 to each node without a sibling" do
      node(:child).position.should == 0
      node(:subchild).position.should == 0
      node(:subsubchild).position.should == 0
    end

    it "should place siblings at the end of the list by default" do
      node(:root).position.should == 0
      node(:other_root).position.should == 1
    end

    it "should move a node to the end of a list when it is moved to a new parent" do
      other_root = node(:other_root)
      child = node(:child)
      child.position.should == 0
      other_root.children << child
      child.reload
      child.position.should == 1
    end

  end

  describe 'when subclassed' do

    before(:each) do
      setup_tree <<-ENDTREE
        - root:
           - child:
             - subchild
           - other_child
        - other_root
      ENDTREE
    end

    it "should allow to store any subclass within the tree" do
      subclassed = SubclassedNode.create!(:name => 'subclassed_subchild')
      node(:child).children << subclassed
      subclassed.root.should == node(:root)
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

    describe ':nullify_children' do
      it "should set its children's parent_id to null" do
        node(:root).nullify_children
        node(:child).should be_root
        node(:subchild).reload.should_not be_descendant_of node(:root)
      end
    end

    describe ':move_children_to_parent' do
      it "should set its childen's parent_id to the documents parent_id" do
        node(:child).move_children_to_parent
        node(:child).should be_leaf
        node(:root).children.to_a.should =~ [node(:child), node(:other_child), node(:subchild)]
      end
    end

    describe ':destroy_children' do
      it "should destroy all children" do
        root = node(:root)
        root.children.should_receive(:destroy_all)
        root.destroy_children
      end
    end

    describe ':delete_descendants' do
      it "should delete all descendants" do
        root = node(:root)
        Node.should_receive(:delete_all).with(:conditions => { :parent_ids => root.id })
        root.delete_descendants
      end
    end

  end

  describe 'utility methods' do

    before(:each) do
      setup_tree <<-ENDTREE
        - root:
           - child:
             - subchild
           - other_child
        - other_root
      ENDTREE
    end

    describe '.root' do
      it "should return the first root document" do
        Node.root.should == node(:root)
      end
    end

    describe '.roots' do
      it "should return all root documents" do
        Node.roots.to_a.should == [node(:root), node(:other_root)]
      end
    end

    describe '.leaves' do
      it "should return all leaf documents" do
        Node.leaves.to_a.should =~ [node(:subchild), node(:other_child), node(:other_root)]
      end
    end

    describe '#root?' do
      it "should return true for root documents" do
        node(:root).should be_root
      end

      it "should return false for non-root documents" do
        node(:child).should_not be_root
      end
    end

    describe '#leaf?' do
      it "should return true for leaf documents" do
        node(:subchild).should be_leaf
        node(:other_child).should be_leaf
        Node.new.should be_leaf
      end

      it "should return false for non-leaf documents" do
        node(:child).should_not be_leaf
        node(:root).should_not be_leaf
      end
    end

    describe '#depth' do
      it "should return the depth of this document" do
        node(:root).depth.should == 0
        node(:child).depth.should == 1
        node(:subchild).depth.should == 2
      end
    end

    describe '#root' do
      it "should return the root for this document" do
        node(:subchild).root.should == node(:root)
      end
    end

    describe 'ancestors' do
      it "#ancestors should return the documents ancestors" do
        node(:subchild).ancestors.to_a.should == [node(:root), node(:child)]
      end

      it "#ancestors_and_self should return the documents ancestors and itself" do
        node(:subchild).ancestors_and_self.to_a.should == [node(:root), node(:child), node(:subchild)]
      end

      describe '#ancestor_of?' do
        it "should return true for ancestors" do
          node(:child).should be_ancestor_of(node(:subchild))
        end

        it "should return false for non-ancestors" do
          node(:other_child).should_not be_ancestor_of(node(:subchild))
        end
      end
    end

    describe 'descendants' do
      it "#descendants should return the documents descendants" do
        node(:root).descendants.to_a.should =~ [node(:child), node(:other_child), node(:subchild)]
      end

      it "#descendants_and_self should return the documents descendants and itself" do
        node(:root).descendants_and_self.to_a.should =~ [node(:root), node(:child), node(:other_child), node(:subchild)]
      end

      describe '#descendant_of?' do
        it "should return true for descendants" do
          subchild = node(:subchild)
          subchild.should be_descendant_of(node(:child))
          subchild.should be_descendant_of(node(:root))
        end

        it "should return false for non-descendants" do
          node(:subchild).should_not be_descendant_of(node(:other_child))
        end
      end
    end

    describe 'siblings' do
      it "#siblings should return the documents siblings" do
        node(:child).siblings.to_a.should == [node(:other_child)]
      end

      it "#siblings_and_self should return the documents siblings and itself" do
        node(:child).siblings_and_self.to_a.should == [node(:child), node(:other_child)]
      end
    end

    describe '#leaves' do
      it "should return this documents leaves" do
        node(:root).leaves.to_a.should =~ [node(:other_child), node(:subchild)]
      end
    end

  end
  
  describe 'utility methods for lists' do
    before(:each) do
      setup_tree <<-ENDTREE
        - first_root:
           - first_child_of_first_root
           - second_child_of_first_root
        - second_root
        - third_root
      ENDTREE
    end

    describe '#lower_items' do
      it "should return a collection of items lower on the list" do
        node(:first_root).lower_items.to_a.should == [node(:second_root), node(:third_root)]
        node(:second_root).lower_items.to_a.should == [node(:third_root)]
        node(:third_root).lower_items.to_a.should == []
        node(:first_child_of_first_root).lower_items.to_a.should == [node(:second_child_of_first_root)]
        node(:second_child_of_first_root).lower_items.to_a.should == []
      end
    end

    describe '#higher_items' do
      it "should return a collection of items lower on the list" do
        node(:first_root).higher_items.to_a.should == []
        node(:second_root).higher_items.to_a.should == [node(:first_root)]
        node(:third_root).higher_items.to_a.should == [node(:first_root), node(:second_root)]
        node(:first_child_of_first_root).higher_items.to_a.should == []
        node(:second_child_of_first_root).higher_items.to_a.should == [node(:first_child_of_first_root)]
      end
    end

    describe '#at_top?' do
      it "should return true when the node is first in the list" do
        node(:first_root).at_top?.should == true
        node(:first_child_of_first_root).at_top?.should == true
      end
      
      it "should return false when the node is not first in the list" do
        node(:second_root).at_top?.should == false
        node(:third_root).at_top?.should == false
        node(:second_child_of_first_root).at_top?.should == false
      end
    end

    describe '#at_bottom?' do
      it "should return true when the node is last in the list" do
        node(:third_root).at_bottom?.should == true
        node(:second_child_of_first_root).at_bottom?.should == true
      end
      
      it "should return false when the node is not last in the list" do
        node(:first_root).at_bottom?.should == false
        node(:second_root).at_bottom?.should == false
        node(:first_child_of_first_root).at_bottom?.should == false
      end
    end
    
    describe '#last_item_in_list' do
      it "should return the last item in the list containing the current item" do
        node(:first_root).last_item_in_list.should == node(:third_root)
        node(:second_root).last_item_in_list.should == node(:third_root)
        node(:third_root).last_item_in_list.should == node(:third_root)
      end
    end

    describe '#first_item_in_list' do
      it "should return the first item in the list containing the current item" do
        node(:first_root).first_item_in_list.should == node(:first_root)
        node(:second_root).first_item_in_list.should == node(:first_root)
        node(:third_root).first_item_in_list.should == node(:first_root)
      end
    end
  end

  describe 'moving nodes around', :focus => true do
    before(:each) do
      setup_tree <<-ENDTREE
        - first_root:
           - first_child_of_first_root
           - second_child_of_first_root
        - second_root:
           - first_child_of_second_root
        - third_root
      ENDTREE
    end

    describe '#move_below' do
      it 'should fix positions within the current list when moving an item away from its current parent' do
        node_to_move = node(:first_child_of_first_root)
        new_parent = node(:second_root)
        node_to_move.move_below(node(:first_child_of_second_root))
        node(:second_child_of_first_root).position.should == 0
      end

      it 'should work when moving to a different parent' do
        node_to_move = node(:first_child_of_first_root)
        new_parent = node(:second_root)
        node_to_move.move_below(node(:first_child_of_second_root))
        node_to_move.reload
        node_to_move.at_bottom?.should == true
        node(:first_child_of_second_root).at_top?.should == true
      end

      it 'should be able to move the first node below the second node' do
        first_node = node(:first_root)
        second_node = node(:second_root)
        first_node.move_below(second_node)
        first_node.reload
        second_node.reload
        second_node.at_top?.should == true
        first_node.higher_items.to_a.should == [second_node]
      end
      
      it 'should be able to move the last node below the first node' do
        first_node = node(:first_root)
        last_node = node(:third_root)
        last_node.move_below(first_node)
        first_node.reload
        last_node.reload
        last_node.at_bottom?.should == false
        node(:second_root).at_bottom?.should == true
        last_node.higher_items.to_a.should == [first_node]
      end
    end

    describe '#move_above' do
      it 'should fix positions within the current list when moving an item away from its current parent' do
        node_to_move = node(:first_child_of_first_root)
        new_parent = node(:second_root)
        node_to_move.move_above(node(:first_child_of_second_root))
        node(:second_child_of_first_root).position.should == 0
      end

      it 'should work when moving to a different parent' do
        node_to_move = node(:first_child_of_first_root)
        new_parent = node(:second_root)
        node_to_move.move_above(node(:first_child_of_second_root))
        node_to_move.reload
        node_to_move.at_top?.should == true
        node(:first_child_of_second_root).at_bottom?.should == true
      end

      it 'should be able to move the last node above the second node' do
        last_node = node(:third_root)
        second_node = node(:second_root)
        last_node.move_above(second_node)
        last_node.reload
        second_node.reload
        second_node.at_bottom?.should == true
        last_node.higher_items.to_a.should == [node(:first_root)]
      end

      it 'should be able to move the first node above the last node' do
        first_node = node(:first_root)
        last_node = node(:third_root)
        first_node.move_above(last_node)
        first_node.reload
        last_node.reload
        node(:second_root).at_top?.should == true
        first_node.higher_items.to_a.should == [node(:second_root)]
      end
    end

    describe "#move_to_top" do
      it "should return true when attempting to move the first item" do
        node(:first_root).move_to_top.should == true
        node(:first_child_of_first_root).move_to_top.should == true
      end
      
      it "should be able to move the last item to the top" do
        first_node = node(:first_root)
        last_node = node(:third_root)
        last_node.move_to_top
        first_node.reload
        last_node.at_top?.should == true
        first_node.at_top?.should == false
        first_node.higher_items.to_a.should == [last_node]
        last_node.lower_items.to_a.should == [first_node, node(:second_root)]
      end
    end

    describe "#move_to_bottom" do
      it "should return true when attempting to move the last item" do
        node(:third_root).move_to_bottom.should == true
        node(:second_child_of_first_root).move_to_bottom.should == true
      end

      it "should be able to move the first item to the bottom" do
        first_node = node(:first_root)
        middle_node = node(:second_root)
        last_node = node(:third_root)
        first_node.move_to_bottom
        middle_node.reload
        last_node.reload
        first_node.at_top?.should == false
        first_node.at_bottom?.should == true
        last_node.at_bottom?.should == false
        last_node.at_top?.should == false
        middle_node.at_top?.should == true
        first_node.lower_items.to_a.should == []
        last_node.higher_items.to_a.should == [middle_node]
      end
    end
  end

  describe 'callbacks' do

    after(:each) do
      Node.reset_callbacks(:rearrange)
    end

    it "should provide a before_rearrange callback" do
      Node.should respond_to :before_rearrange
    end

    it "should provida an after_rearrange callback" do
      Node.should respond_to :after_rearrange
    end

    describe 'before rearrange callback' do

      it "should be called before the document is rearranged" do
        Node.before_rearrange :callback
        node = Node.new
        node.should_receive(:callback).ordered
        node.should_receive(:rearrange).ordered
        node.save
      end

    end

    describe 'after rearrange callback' do

      it "should be called after the document is rearranged" do
        Node.after_rearrange :callback
        node = Node.new
        node.should_receive(:rearrange).ordered
        node.should_receive(:callback).ordered
        node.save
      end

    end

  end
end
