# frozen_string_literal: true

module Query
  module Modules
    # methods for moving forward/back up/down in Query results
    module SequenceOperators
      # Current place in results, as an id.  (Returns nil if not set yet.)
      attr_reader :current_id

      # Set current place in results; takes id (String or Integer).
      def current_id=(id)
        @save_current_id = @current_id = id.to_s.to_i
      end

      # Reset current place in results to place last given in a "current=" call.
      def reset
        @current_id = @save_current_id
      end

      # Current place in results, instantiated.  (Returns nil if not set yet.)
      def current(*args)
        @current_id ? instantiate([@current_id], *args).first : nil
      end

      # Set current place in results; takes instance or id (String or Integer).
      def current=(arg)
        if arg.is_a?(model)
          @results ||= {}
          @results[arg.id] = arg
          self.current_id = arg.id
        else
          self.current_id = arg
        end
        arg
      end

      # Move to first place.
      def first(skip_outer = false)
        new_self = self
        new_self = outer_first if !skip_outer && outer?
        id = new_self.select_value(limit: "1").to_i
        if id.positive?
          if new_self == self
            @current_id = id
          else
            new_self.current_id = id
          end
        else
          new_self = nil
        end
        new_self
      end

      # Move to previous place.
      def prev
        new_self = self
        index = result_ids.index(current_id)
        if !index
          new_self = nil
        elsif index.positive?
          if new_self == self
            @current_id = result_ids[index - 1]
          else
            new_self.current_id = result_ids[index - 1]
          end
        elsif outer?
          new_self = prev_inner(new_self)
        else
          new_self = nil
        end
        new_self
      end

      def prev_inner(new_self)
        while (new_self = new_self.outer_prev)
          if (new_new_self = new_self.last(:skip_outer))
            new_self = new_new_self
            break
          end
        end
        new_self
      end

      # Move to next place.
      def next
        new_self = self
        index = result_ids.index(current_id)
        if !index
          new_self = nil
        elsif index < result_ids.length - 1
          if new_self == self
            @current_id = result_ids[index + 1]
          else
            new_self.current_id = result_ids[index + 1]
          end
        elsif outer?
          new_self = next_inner(new_self)
        else
          new_self = nil
        end
        new_self
      end

      def next_inner(new_self)
        while (new_self = new_self.outer_next)
          if (new_new_self = new_self.first(:skip_outer))
            new_self = new_new_self
            break
          end
        end
        new_self
      end

      # Move to last place.
      def last(skip_outer = false)
        new_self = self
        new_self = outer_last if !skip_outer && outer?
        id = new_self.select_value(order: :reverse, limit: "1").to_i
        if id.positive?
          if new_self == self
            @current_id = id
          else
            new_self.current_id = id
          end
        else
          new_self = nil
        end
        new_self
      end
    end
  end
end
