require 'spec_helper'

describe Mongoid::Tree do

  subject { Node }

  it "should reference many children as inverse of parent with index" do
    a = Node.reflect_on_association(:children)
    expect(a).to be
    expect(a.macro).to eq(:has_many)
    expect(a.class_name).to eq('Node')
    expect(a.foreign_key).to eq('parent_id')
    expect(Node.index_options).to have_key(:parent_id => 1)
  end

  it "should be referenced in one parent as inverse of children" do
    a = Node.reflect_on_association(:parent)
    expect(a).to be
    expect(a.macro).to eq(:belongs_to)
    expect(a.class_name).to eq('Node')
    expect(a.inverse_of).to eq(:children)
  end

  it "should store parent_ids as Array with [] as default with index" do
    f = Node.fields['parent_ids']
    expect(f).to be
    expect(f.options[:type]).to eq(Array)
    expect(f.options[:default]).to eq([])
    expect(Node.index_options).to have_key(:parent_ids => 1)
  end

  describe 'when new' do
    it "should not require a saved parent when adding children" do
      root = Node.new(:name => 'root'); child = Node.new(:name => 'child')
      expect { root.children << child; root.save! }.to_not raise_error
      expect(child).to be_persisted
    end

    it "should not be saved when parent is not saved" do
      root = Node.new(:name => 'root'); child = Node.new(:name => 'child')
      expect(child).not_to receive(:save)
      root.children << child
    end

    it "should save its unsaved children" do
      root = Node.new(:name => 'root'); child = Node.new(:name => 'child')
      root.children << child
      expect(child).to receive(:save)
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
      expect(child.parent).to eq(root)
      expect(child.parent_id).to eq(root.id)
    end

    it "should set the child's parent_id parent is set on child" do
      root = Node.create; child = Node.create
      child.parent = root
      expect(child.parent).to eq(root)
      expect(child.parent_id).to eq(root.id)
    end

    it "should rebuild its parent_ids" do
      root = Node.create; child = Node.create
      root.children << child
      expect(child.parent_ids).to eq([root.id])
    end

    it "should rebuild its children's parent_ids when its own parent_ids changed" do
      other_root = node(:other_root); child = node(:child); subchild = node(:subchild);
      other_root.children << child
      subchild.reload # To get the updated version
      expect(subchild.parent_ids).to eq([other_root.id, child.id])
    end

    it "should correctly rebuild its descendants' parent_ids when moved into an other subtree" do
      subchild = node(:subchild); subsubchild = node(:subsubchild); other_child = node(:other_child)
      other_child.children << subchild
      subsubchild.reload
      expect(subsubchild.parent_ids).to eq([node(:other_root).id, other_child.id, subchild.id])
    end

    it "should rebuild its children's parent_ids when its own parent_id is removed" do
      c = node(:child)
      c.parent_id = nil
      c.save
      expect(node(:subchild).parent_ids).to eq([node(:child).id])
    end

    it "should not rebuild its children's parent_ids when it's not required" do
      root = node(:root)
      expect(root).not_to receive(:rearrange_children)
      root.save
    end

    it "should prevent cycles" do
      child = node(:child)
      child.parent = node(:subchild)
      expect(child).not_to be_valid
      expect(child.errors[:parent_id]).not_to be_nil
    end

    it "should save its children when added" do
      new_child = Node.new(:name => 'new_child')
      node(:root).children << new_child
      expect(new_child).to be_persisted
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
      expect(subclassed.root).to eq(node(:root))
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
        expect(node(:child)).to be_root
        expect(node(:subchild).reload).not_to be_descendant_of node(:root)
      end
    end

    describe ':move_children_to_parent' do
      it "should set its childen's parent_id to the documents parent_id" do
        node(:child).move_children_to_parent
        expect(node(:child)).to be_leaf
        expect(node(:root).children.to_a).to match_array([node(:child), node(:other_child), node(:subchild)])
      end

      it "should be able to handle a missing parent" do
        node(:root).delete
        expect { node(:child).move_children_to_parent }.to_not raise_error
      end
    end

    describe ':destroy_children' do
      it "should destroy all children" do
        root = node(:root)
        expect(root.children).to receive(:destroy_all)
        root.destroy_children
      end
    end

    describe ':delete_descendants' do
      it "should delete all descendants" do
        root = node(:root)
        expect(Node).to receive(:delete_all).with(:conditions => { :parent_ids => root.id })
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
        expect(Node.root).to eq(node(:root))
      end
    end

    describe '.roots' do
      it "should return all root documents" do
        expect(Node.roots.to_a).to eq([node(:root), node(:other_root)])
      end
    end

    describe '.leaves' do
      it "should return all leaf documents" do
        expect(Node.leaves.to_a).to match_array([node(:subchild), node(:other_child), node(:other_root)])
      end
    end

    describe '#root?' do
      it "should return true for root documents" do
        expect(node(:root)).to be_root
      end

      it "should return false for non-root documents" do
        expect(node(:child)).not_to be_root
      end
    end

    describe '#leaf?' do
      it "should return true for leaf documents" do
        expect(node(:subchild)).to be_leaf
        expect(node(:other_child)).to be_leaf
        expect(Node.new).to be_leaf
      end

      it "should return false for non-leaf documents" do
        expect(node(:child)).not_to be_leaf
        expect(node(:root)).not_to be_leaf
      end
    end

    describe '#depth' do
      it "should return the depth of this document" do
        expect(node(:root).depth).to eq(0)
        expect(node(:child).depth).to eq(1)
        expect(node(:subchild).depth).to eq(2)
      end
    end

    describe '#root' do
      it "should return the root for this document" do
        expect(node(:subchild).root).to eq(node(:root))
      end

      it "should return itself when there is no root" do
        new_node = Node.new
        expect(new_node.root).to be(new_node)
      end

      it "should return it root when it's not saved yet" do
        root = Node.new(:name => 'root')
        new_node = Node.new(:name => 'child')
        new_node.parent = root
        expect(new_node.root).to be(root)
      end
    end

    describe 'ancestors' do
      describe '#ancestors' do
        it "should return the documents ancestors" do
          expect(node(:subchild).ancestors.to_a).to eq([node(:root), node(:child)])
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

        it 'should return nothing when there are no ancestors' do
          root = Node.new(:name => 'root')
          expect(root.ancestors).to be_empty
        end

        it 'should allow chaning of other `or`-criterias' do
          setup_tree <<-ENDTREE
            - root:
              - child:
                - subchild:
                  - subsubchild
          ENDTREE

          filtered_ancestors = node(:subsubchild).ancestors.or(
              { :name => 'child' },
              { :name => 'subchild' }
          )

          expect(filtered_ancestors.to_a).to eq([node(:child), node(:subchild)])
        end
      end

      describe '#ancestors_and_self' do
        it "should return the documents ancestors and itself" do
          expect(node(:subchild).ancestors_and_self.to_a).to eq([node(:root), node(:child), node(:subchild)])
        end
      end

      describe '#ancestor_of?' do
        it "should return true for ancestors" do
          expect(node(:child)).to be_ancestor_of(node(:subchild))
        end

        it "should return false for non-ancestors" do
          expect(node(:other_child)).not_to be_ancestor_of(node(:subchild))
        end
      end
    end

    describe 'descendants' do
      describe '#descendants' do
        it "should return the documents descendants" do
          expect(node(:root).descendants.to_a).to match_array([node(:child), node(:other_child), node(:subchild)])
        end
      end

      describe '#descendants_and_self' do
        it "should return the documents descendants and itself" do
          expect(node(:root).descendants_and_self.to_a).to match_array([node(:root), node(:child), node(:other_child), node(:subchild)])
        end
      end

      describe '#descendant_of?' do
        it "should return true for descendants" do
          subchild = node(:subchild)
          expect(subchild).to be_descendant_of(node(:child))
          expect(subchild).to be_descendant_of(node(:root))
        end

        it "should return false for non-descendants" do
          expect(node(:subchild)).not_to be_descendant_of(node(:other_child))
        end
      end
    end

    describe 'siblings' do
      describe '#siblings' do
        it "should return the documents siblings" do
          expect(node(:child).siblings.to_a).to eq([node(:other_child)])
        end
      end

      describe '#siblings_and_self' do
        it "should return the documents siblings and itself" do
          expect(node(:child).siblings_and_self).to be_kind_of(Mongoid::Criteria)
          expect(node(:child).siblings_and_self.to_a).to eq([node(:child), node(:other_child)])
        end
      end

      describe '#sibling_of?' do
        it "should return true for siblings" do
          expect(node(:child)).to be_sibling_of(node(:other_child))
        end

        it "should return false for non-siblings" do
          expect(node(:root)).not_to be_sibling_of(node(:other_child))
        end
      end
    end

    describe '#leaves' do
      it "should return this documents leaves" do
        expect(node(:root).leaves.to_a).to match_array([node(:other_child), node(:subchild)])
      end
    end

  end

  describe 'callbacks' do

    after(:each) do
      Node.reset_callbacks(:rearrange)
    end

    it "should provide a before_rearrange callback" do
      expect(Node).to respond_to :before_rearrange
    end

    it "should provida an after_rearrange callback" do
      expect(Node).to respond_to :after_rearrange
    end

    describe 'before rearrange callback' do

      it "should be called before the document is rearranged" do
        Node.before_rearrange :callback
        node = Node.new
        expect(node).to receive(:callback).ordered
        expect(node).to receive(:rearrange).ordered
        node.save
      end

    end

    describe 'after rearrange callback' do

      it "should be called after the document is rearranged" do
        Node.after_rearrange :callback
        node = Node.new
        expect(node).to receive(:rearrange).ordered
        expect(node).to receive(:callback).ordered
        node.save
      end

    end

    describe 'cascading to embedded documents' do

      it 'should not raise a NoMethodError' do
        node = NodeWithEmbeddedDocument.new
        document = node.build_embedded_document
        expect { node.save }.to_not raise_error
      end

    end

  end
end
