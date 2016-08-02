module Query::Modules::Coercion
  # Attempt to coerce a query for one model into a related query for another
  # model.  This is currently only defined for a very few specific cases.  I
  # have no idea how to generalize it.  Returns a new Query in rare successful
  # cases; returns +nil+ in all other cases.
  def coerce(new_model, just_test = false)
    old_model  = model.to_s.to_sym
    old_flavor = flavor
    new_model  = new_model.to_s.to_sym

    # Trivial case: model not actually changing!
    if old_model == new_model
      self

    # Going from list_rss_logs to showing observation, name, etc.
    elsif (old_model == :RssLog) &&
       (old_flavor == :all) &&
       (begin
          new_model.to_s.constantize.reflect_on_association(:rss_log)
        rescue
          false
        end)
      just_test || begin
        params2 = params.dup
        params2.delete(:type)
        Query.lookup(new_model, :by_rss_log, params2)
      end

    # Going from objects with observations to those observations themselves.
    elsif ((new_model == :Observation) &&
            [:Image, :Location, :Name].include?(old_model) &&
            old_flavor.to_s.match(/^with_observations/)) ||
          ((new_model == :LocationDescription) &&
            (old_model == :Location) &&
            old_flavor.to_s.match(/^with_descriptions/)) ||
          ((new_model == :NameDescription) &&
            (old_model == :Name) &&
            old_flavor.to_s.match(/^with_descriptions/))
      just_test || begin
        if old_flavor.to_s.match(/^with_[a-z]+$/)
          new_flavor = :all
        else
          new_flavor = old_flavor.to_s.sub(/^with_[a-z]+_/, "").to_sym
        end
        params2 = params.dup
        if params2[:title]
          params2[:title] = "raw " + title
        elsif params2[:old_title]
          # This is passed through from previous coerce.
          params2[:title] = "raw " + params2[:old_title]
          params2.delete(:old_title)
        end
        if params2[:old_by]
          # This is passed through from previous coerce.
          params2[:by] = params2[:old_by]
          params2.delete(:old_by)
        elsif params2[:by]
          # Can't be sure old sort order will continue to work.
          params2.delete(:by)
        end
        Query.lookup(new_model, new_flavor, params2)
      end

    # Going from observations to objects with those observations.
    elsif ((old_model == :Observation) &&
            [:Image, :Location, :Name].include?(new_model)) ||
          ((old_model == :LocationDescription) &&
            (new_model == :Location)) ||
          ((old_model == :NameDescription) &&
            (new_model == :Name))
      just_test || begin
        if old_model == :Observation
          type1 = :observations
          type2 = :observation
        else
          type1 = :descriptions
          type2 = old_model.to_s.underscore.to_sym
        end
        if old_flavor == :all
          new_flavor = :"with_#{type1}"
        else
          new_flavor = :"with_#{type1}_#{old_flavor}"
        end
        params2 = params.dup
        if params2[:title]
          # This can spiral out of control, but so be it.
          params2[:title] = "raw " +
                            :"query_title_with_#{type2}s_in_set".
                            t(observations: title, type: new_model.to_s.underscore.to_sym)
        end
        if params2[:by]
          # Can't be sure old sort order will continue to work.
          params2.delete(:by)
        end
        if old_flavor == :in_set
          params2.delete(:title) if params2.key?(:title)
          Query.lookup(new_model, :"with_#{type1}_in_set",
                            params2.merge(old_title: title, old_by: params[:by]))
        elsif old_flavor == :advanced_search || old_flavor == :pattern_search
          params2.delete(:title) if params2.key?(:title)
          Query.lookup(new_model, :"with_#{type1}_in_set",
                            ids: result_ids, old_title: title, old_by: params[:by])
        elsif (new_model == :Location) &&
              (old_flavor == :at_location)
          Query.lookup(new_model, :in_set,
                            ids: params2[:location])
        elsif (new_model == :Name) &&
              (old_flavor == :of_name)
          # TODO: -- need 'synonyms' flavor
          # params[:synonyms] == :all / :no / :exclusive
          # params[:misspellings] == :either / :no / :only
          nil
        elsif recognized_flavor?(new_model, new_flavor)
          Query.lookup(new_model, new_flavor, params2)
        end
      end
    end
  end

  def recognized_flavor?(model, flavor)
    klass = "Query::#{model}#{flavor.to_s.camelize}"
    klass.constantize
    true
  rescue NameError
    false
  end
end
