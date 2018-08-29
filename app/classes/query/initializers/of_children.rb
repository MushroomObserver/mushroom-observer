module Query
  module Initializers
    # Helps with initialization of "of_children" queries.
    module OfChildren
      def add_name_condition(name)
        # If "all" is true, get all descendants, not just immediate children.
        all = params[:all]
        all = false if params[:all].nil?
        if name.at_or_below_genus?
          add_name_condition_below_genus(name, all)
        else
          add_name_condition_above_genus(name, all)
        end
      end

      # If we have to rely on classification strings, just let Name do it, and
      # create a pseudo-query based on ids returned by +name.children+.
      def add_name_condition_above_genus(name, all)
        set = clean_id_set(name.children(all).map(&:id))
        where << "names.id IN (#{set})"
      end

      # If at genus or below, we can deduce hierarchy purely by syntax.
      # Note, this will show species below genus, not subgenera etc.
      def add_name_condition_below_genus(name, all)
        where << "names.text_name LIKE '#{name.text_name} %'"
        return if all
        pat = name.rank == :Genus ? "% %" : "% % %"
        where << "names.text_name NOT LIKE '#{name.text_name} #{pat}'"
      end
    end
  end
end
