require 'spec_helper'

class Node
  include Mongoid::Document
  include Mongoid::Tree
end

describe Mongoid::Tree do
  
  it "should reference many children as inverse of parent" do
    a = Node.associations['children']
    a.should_not be_nil
    a.association.should == Mongoid::Associations::ReferencesMany
    a.options.class_name.should == 'Node'
    a.options.foreign_key.should == 'parent_id'
    a.options.inverse_of.should == :parent
  end
  
  it "should be referenced in one parent as inverse of children" do
    a = Node.associations['parent']
    a.should_not be_nil
    a.association.should == Mongoid::Associations::ReferencedIn
    a.options.class_name.should == 'Node'
    a.options.inverse_of.should == :children
  end
  
  it "should store parent_ids as Array with [] as default" do
    f = Node.fields['parent_ids']
    f.should_not be_nil
    f.options[:type].should == Array
    f.options[:default].should == []
  end
  
  describe 'when saved' do
    
    it "should rebuild its parent_ids" do
      root = Node.create; child = Node.create; subchild = Node.create
      root.children << child
      child.children << subchild # Mongoid implicitly saves
      subchild.parent_ids.should == [root.id, child.id]
    end
  
    it "should rebuild its children's parent_ids when its own parent_ids changed" do
      root = Node.create; child = Node.create; subchild = Node.create; new_root = Node.create
      root.children << child
      child.children << subchild
    
      new_root.children << child
    
      subchild.reload
      subchild.parent_ids.should == [new_root.id, child.id]
    end
  
    it "should correctly rebuild its descendants' parent_ids when moved into an other subtree" do
      root = Node.create; child = Node.create; subchild = Node.create; subsubchild = Node.create
      new_root = Node.create; new_child = Node.create
    
      root.children << child 
      child.children << subchild
      subchild.children << subsubchild
  
      subsubchild.parent_ids.should == [root.id, child.id, subchild.id]
    
      new_root.children << new_child
      new_child.children << subchild
      subsubchild.reload
      subsubchild.parent_ids.should == [new_root.id, new_child.id, subchild.id]
    end
  
    it "should not rebuild its children's parent_ids when it's not required" do
      root = Node.create; child = Node.create; 
      root.children << child
      root.should_not_receive(:rearrange_children)
      root.save
    end
  
  end
  
  describe 'utility methods' do
    
    let!(:root) { Node.create }
    let!(:child) { root.children << n = Node.create; n }
    let!(:other_child) { root.children << n = Node.create; n }
    let!(:subchild) { child.children << n = Node.create; n }
    
    describe '.root?' do
      it "should return true for root documents" do
        root.should be_root
      end
      
      it "should return false for non-root documents" do
        child.should_not be_root
      end
    end
    
    describe '.leaf?' do
      it "should return true for leaf documents" do
        subchild.should be_leaf
        Node.new.should be_leaf
      end
      
      it "should return false for non-leaf documents" do
        child.should_not be_leaf
        root.should_not be_leaf
      end
    end
    
    describe '.root' do
      it "should return the root for this document" do
        subchild.root.should == root
      end
    end
    
    describe 'ancestors' do
      it ".ancestors should return the documents ancestors" do
        subchild.ancestors.to_a.should == [root, child]
      end
    
      it ".ancestors_and_self should return the documents ancestors and itself" do
        subchild.ancestors_and_self.to_a.should == [root, child, subchild]
      end
      
      describe '.ancestor_of?' do
        it "should return true for ancestors" do
          child.should be_ancestor_of(subchild)
        end
        
        it "should return false for non-ancestors" do
          other_child.should_not be_ancestor_of(subchild)
        end
      end
    end
    
    describe 'descendants' do
      it ".descendants should return the documents descendants" do
        root.descendants.to_a.should == [child, other_child, subchild]
      end
    
      it ".descendants_and_self should return the documents descendants and itself" do
        root.descendants_and_self.to_a.should == [root, child, other_child, subchild]
      end
      
      describe '.descendant_of?' do
        it "should return true for descendants" do
          subchild.should be_descendant_of(child)
          subchild.should be_descendant_of(root)
        end
        
        it "should return false for non-descendants" do
          subchild.should_not be_descendant_of(other_child)
        end
      end
    end

    describe 'siblings' do
      it ".siblings should return the documents siblings" do
        child.siblings.to_a.should == [other_child]
      end
      
      it ".siblings_and_self should return the documents siblings and itself" do
        child.siblings_and_self.to_a.should == [child, other_child]
      end
    end
    
  end
  
end