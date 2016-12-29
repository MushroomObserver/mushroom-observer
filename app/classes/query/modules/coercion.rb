module Query::Modules::Coercion
  def is_coercable?(new_model)
    !!coerce(new_model, :just_test)
  end

  # Attempt to coerce a query for one model into a related query for another
  # model.  Returns a new Query or true if successful; returns +nil+ otherwise. 
  def coerce(new_model, just_test = false)
    old_model = model.to_s
    new_model = new_model.to_s
    return self if old_model == new_model
    test_method   = "coerce_into_#{new_model.underscore}_query?"
    coerce_method = "coerce_into_#{new_model.underscore}_query"
    if respond_to?(test_method)
      return nil unless self.send(test_method)
      return true if just_test
      return self.send(coerce_method)
    elsif respond_to?(coerce_method)
      return true if just_test
      return self.send(coerce_method)
    else
      return nil
    end
  end

  # If coercing to blah_with_observations or blah_with_descriptions queries,
  # save current sort order in the unused parameter "old_by" so we can restore
  # it if coerced back later. (See below.)
  def params_plus_old_by
    params2 = params.dup
    params2.delete(:by)
    add_old_by(params2)
  end

  # If returning back to observation or description query, this restores the
  # original sort order (kept silently in "old_by"). (See above.)
  def params_with_old_by_restored
    params2 = params.dup
    params2.delete(:by)
    params2.delete(:old_by)
    params2.delete(:old_title)
    params2[:by] = params[:old_by] if params.has_key?(:old_by)
    return params2
  end

  # Save current sort order to a hash of parameters as "old_by".
  def add_old_by(hash)
    return hash unless params.has_key?(:by)
    hash[:old_by] = params[:by]
    return hash
  end

  # Save current title to a hash of parameters as "old_title".
  def add_old_title(hash)
    hash[:old_title] = title
    return hash
  end
end
