module Mongoid
  module Tree
    ##
    # = Mongoid::Tree::Ordering
    #
    # Mongoid::Tree doesn't order the tree by default. To enable ordering of children
    # include both Mongoid::Tree and Mongoid::Tree::Ordering into your document.
    #
    # == Utility methods
    #
    # This module adds methods to get related siblings depending on their position:
    #
    #    node.lower_siblings
    #    node.higher_siblings
    #    node.first_sibling_in_list
    #    node.last_sibling_in_list
    #
    # There are several methods to move nodes around in the list:
    #
    #    node.move_up
    #    node.move_down
    #    node.move_to_top
    #    node.move_to_bottom
    #    node.move_above(other)
    #    node.move_below(other)
    #
    # Additionally there are some methods to check aspects of the document
    # in the list of children:
    #
    #    node.at_top?
    #    node.at_bottom?
    module Ordering
      extend ActiveSupport::Concern

      included do
        field :position, :type => Integer

        default_scope asc(:position)

        before_save :assign_default_position, :if => :assign_default_position?
        before_save :reposition_former_siblings, :if => :sibling_reposition_required?
        after_destroy :move_lower_siblings_up
      end

      ##
      # Returns a chainable criteria for this document's ancestors
      #
      # @return [Mongoid::Criteria] Mongoid criteria to retrieve the document's ancestors
      def ancestors
        base_class.unscoped { super }
      end

      ##
      # Returns siblings below the current document.
      # Siblings with a position greater than this document's position.
      #
      # @return [Mongoid::Criteria] Mongoid criteria to retrieve the document's lower siblings
      def lower_siblings
        self.siblings.where(:position.gt => self.position)
      end

      ##
      # Returns siblings above the current document.
      # Siblings with a position lower than this document's position.
      #
      # @return [Mongoid::Criteria] Mongoid criteria to retrieve the document's higher siblings
      def higher_siblings
        self.siblings.where(:position.lt => self.position)
      end

      ##
      # Returns siblings between the current document and the other document
      # Siblings with a position between this document's position and the other document's position.
      #
      # @return [Mongoid::Criteria] Mongoid criteria to retrieve the documents between this and the other document
      def siblings_between(other)
        range = [self.position, other.position].sort
        self.siblings.where(:position.gt => range.first, :position.lt => range.last)
      end

      ##
      # Returns the lowest sibling (could be self)
      #
      # @return [Mongoid::Document] The lowest sibling
      def last_sibling_in_list
        siblings_and_self.last
      end

      ##
      # Returns the highest sibling (could be self)
      #
      # @return [Mongoid::Document] The highest sibling
      def first_sibling_in_list
        siblings_and_self.first
      end

      ##
      # Is this the highest sibling?
      #
      # @return [Boolean] Whether the document is the highest sibling
      def at_top?
        higher_siblings.empty?
      end

      ##
      # Is this the lowest sibling?
      #
      # @return [Boolean] Whether the document is the lowest sibling
      def at_bottom?
        lower_siblings.empty?
      end

      ##
      # Move this node above all its siblings
      #
      # @return [undefined]
      def move_to_top
        return true if at_top?
        move_above(first_sibling_in_list)
      end

      ##
      # Move this node below all its siblings
      #
      # @return [undefined]
      def move_to_bottom
        return true if at_bottom?
        move_below(last_sibling_in_list)
      end

      ##
      # Move this node one position up
      #
      # @return [undefined]
      def move_up
        switch_with_sibling_at_offset(-1) unless at_top?
      end

      ##
      # Move this node one position down
      #
      # @return [undefined]
      def move_down
        switch_with_sibling_at_offset(1) unless at_bottom?
      end

      ##
      # Move this node above the specified node
      #
      # This method changes the node's parent if nescessary.
      #
      # @param [Mongoid::Tree] other document to move this document above
      #
      # @return [undefined]
      def move_above(other)
        ensure_to_be_sibling_of(other)

        if position > other.position
          new_position = other.position
          self.siblings_between(other).inc(:position, 1)
          other.inc(:position, 1)
        else
          new_position = other.position - 1
          self.siblings_between(other).inc(:position, -1)
        end

        self.position = new_position
        save!
      end

      ##
      # Move this node below the specified node
      #
      # This method changes the node's parent if nescessary.
      #
      # @param [Mongoid::Tree] other document to move this document below
      #
      # @return [undefined]
      def move_below(other)
        ensure_to_be_sibling_of(other)

        if position > other.position
          new_position = other.position + 1
          self.siblings_between(other).inc(:position, 1)
        else
          new_position = other.position
          self.siblings_between(other).inc(:position, -1)
          other.inc(:position, -1)
        end

        self.position = new_position
        save!
      end

    private

      def switch_with_sibling_at_offset(offset)
        siblings.where(:position => self.position + offset).first.inc(:position, -offset)
        inc(:position, offset)
      end

      def ensure_to_be_sibling_of(other)
        return if sibling_of?(other)
        self.parent_id = other.parent_id
        save!
      end

      def move_lower_siblings_up
        lower_siblings.inc(:position, -1)
      end

      def reposition_former_siblings
        former_siblings = base_class.where(:parent_id => attribute_was('parent_id')).
                                     and(:position.gt => (attribute_was('position') || 0)).
                                     excludes(:id => self.id)
        former_siblings.inc(:position,  -1)
      end

      def sibling_reposition_required?
        parent_id_changed? && persisted?
      end

      def assign_default_position
        self.position = if self.siblings.where(:position.ne => nil).any?
          self.last_sibling_in_list.position + 1
        else
          0
        end
      end

      def assign_default_position?
        self.position.nil? || self.parent_id_changed?
      end
    end
  end
end
