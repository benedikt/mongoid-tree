module Mongoid
  module Tree
    module Ordering
      extend ActiveSupport::Concern

      included do
        references_many :children, :class_name => self.name, :foreign_key => :parent_id, :inverse_of => :parent, :default_order => :position.asc

        field :position, :type => Integer

        after_rearrange :assign_default_position
      end

      ##
      # Returns lower siblings
      def lower_siblings
        self.siblings.where(:position.gt => self.position)
      end

      ##
      # Returns higher siblings
      def higher_siblings
        self.siblings.where(:position.lt => self.position)
      end

      ##
      # Returns the lowest sibling (could be self)
      def last_sibling_in_list
        siblings_and_self.asc(:position).last
      end

      ##
      # Returns the highest sibling (could be self)
      def first_sibling_in_list
        siblings_and_self.asc(:position).first
      end

      ##
      # Is this the highest sibling?
      def at_top?
        higher_siblings.empty?
      end

      ##
      # Is this the lowest sibling?
      def at_bottom?
        lower_siblings.empty?
      end

      ##
      # Move this node above all its siblings
      def move_to_top
        return true if at_top?
        move_above(first_sibling_in_list)
      end

      ##
      # Move this node below all its siblings
      def move_to_bottom
        return true if at_bottom?
        move_below(last_sibling_in_list)
      end

      ##
      # Move this node above the specified node
      def move_above(other)
        if parent_id != other.parent_id
          move_lower_siblings_up
          self.parent_id = other.parent_id
          self.save! # So that the rearrange callback happens
          self.move_above(other)
        else
          if position > other.position
            new_position = other.position
            other.lower_siblings.where(:position.lt => self.position).each do |sibling|
              sibling.inc(:position, 1)
            end
            other.inc(:position, 1)
            self.update_attributes!(:position => new_position)
          else
            new_position = other.position - 1
            other.higher_siblings.where(:position.gt => self.position).each do |sibling|
              sibling.inc(:position, -1)
            end
            self.update_attributes!(:position => new_position)
          end
        end
      end

      ##
      # Move this node below the specified node
      def move_below(other)
        if parent_id != other.parent_id
          move_lower_siblings_up
          self.parent_id = other.parent_id
          self.save! # So that the rearrange callback happens
          self.move_below(other)
        else
          if position > other.position
            new_position = other.position + 1
            other.lower_siblings.where(:position.lt => self.position).each do |sibling|
              sibling.inc(:position, 1)
            end
            self.update_attributes!(:position => new_position)
          else
            new_position = other.position
            other.higher_siblings.where(:position.gt => self.position).each do |sibling|
              sibling.inc(:position, -1)
            end
            other.inc(:position, -1)
            self.update_attributes!(:position => new_position)
          end
        end
      end

    private
      def move_lower_siblings_up
        lower_siblings.each do |sibling|
          sibling.inc(:position, -1)
        end
      end

      def assign_default_position
        self.position = nil if self.parent_ids_changed?

        if self.position.nil?
          if self.siblings.empty? || (self.siblings.collect(&:position).uniq == [nil])
            self.position = 0
          else
            self.position = self.siblings.collect(&:position).reject {|p| p.nil?}.max + 1
          end
        end
      end
    end # Ordering
  end # Tree
end # Mongoid
