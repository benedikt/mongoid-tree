require 'spec_helper'

describe Mongoid::Tree do

  subject { Node }

  it "should reference many children as inverse of parent with index" do
    a = Node.reflect_on_association(:children)
    a.should be
    a.macro.should eql(:references_many)
    a.class_name.should eql('Node')
    a.foreign_key.should eql('parent_id')
    Node.index_options.should have_key('parent_id')
  end

  it "should be referenced in one parent as inverse of children" do
    a = Node.reflect_on_association(:parent)
    a.should be
    a.macro.should eql(:referenced_in)
    a.class_name.should eql('Node')
    a.inverse_of.should eql(:children)
  end

  it "should store parent_ids as Array with [] as default with index" do
    f = Node.fields['parent_ids']
    f.should be
    f.options[:type].should eql(Array)
    f.options[:default].should eql([])
    Node.index_options.should have_key(:parent_ids)
  end

  describe 'when new' do
    it "should not require a saved parent when adding children" do
      root = Node.new(:name => 'root'); child = Node.new(:name => 'child')
      expect { root.children << child; root.save! }.to_not raise_error(Mongoid::Errors::DocumentNotFound)
      child.should be_persisted
    end

    it "should not be saved when parent is not saved" do
      root = Node.new(:name => 'root'); child = Node.new(:name => 'child')
      child.should_not_receive(:save)
      root.children << child
    end

    it "should save its unsaved children" do
      root = Node.new(:name => 'root'); child = Node.new(:name => 'child')
      root.children << child
      child.should_receive(:save).at_most(2).times
      root.save
    end
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
      c = node(:child)
      c.parent_id = nil
      c.save
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

    it "should save its children when added" do
      new_child = Node.new(:name => 'new_child')
      node(:root).children << new_child
      new_child.should be_persisted
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

      it "should return itself when there is no root" do
        new_node = Node.new
        new_node.root.should be(new_node)
      end

      it "should return it root when it's not saved yet" do
        root = Node.new(:name => 'root')
        new_node = Node.new(:name => 'child')
        new_node.parent = root
        new_node.root.should be(root)
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
        node(:child).siblings_and_self.is_a?(Mongoid::Criteria).should == true
        node(:child).siblings_and_self.to_a.should == [node(:child), node(:other_child)]
      end

      describe '#sibling_of?' do
        it "should return true for siblings" do
          node(:child).should be_sibling_of(node(:other_child))
        end

        it "should return false for non-siblings" do
          node(:root).should_not be_sibling_of(node(:other_child))
        end
      end
    end

    describe '#leaves' do
      it "should return this documents leaves" do
        node(:root).leaves.to_a.should =~ [node(:other_child), node(:subchild)]
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
