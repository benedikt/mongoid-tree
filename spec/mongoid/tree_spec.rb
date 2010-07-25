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
  
  it "should rebuild its parent_ids when saved" do
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
  
  it "should not rebuild its children's parent_ids when its not required" do
    root = Node.create; child = Node.create; 
    root.children << child
    root.should_not_receive(:rearrange_children)
    root.save
  end
  
end