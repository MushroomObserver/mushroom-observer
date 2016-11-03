module Query::Initializers::OfChildren
  def add_name_condition(name)
    # If "all" is true, get all descendants, not just immediate children.
    all = params[:all]
    all = false if params[:all].nil?

    # If at genus or below, we can deduce hierarchy purely by syntax.
    # (Why would we not do this if all == true??)
    if name.at_or_below_genus? # && !all
      self.where << "names.text_name LIKE '#{name.text_name} %'"
      unless all
        if name.rank == :Genus
          self.where << "names.text_name NOT LIKE '#{name.text_name} % %'"
        else
          self.where << "names.text_name NOT LIKE '#{name.text_name} % % %'"
        end
      end

    # If we have to rely on classification strings, just let Name do it, and
    # create a pseudo-query based on ids returned by +name.children+.
    else
      set = clean_id_set(name.children(all).map(&:id))
      self.where << "names.id IN (#{set})"
    end
  end
end
