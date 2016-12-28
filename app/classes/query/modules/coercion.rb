module Query::Modules::Coercion
  def is_coercable?(new_model)
    coerce(new_model, :just_test)
  end

  # Attempt to coerce a query for one model into a related query for another
  # model.  Returns a new Query or true if successful; returns +nil+ otherwise. 
  def coerce(new_model, just_test = false)
    old_model = model.to_s
    new_model = new_model.to_s
    return self if old_model == new_model
    test_method   = "coerce_into_#{new_model.underscore}?"
    coerce_method = "coerce_into_#{new_model.underscore}"
    if respond_to?(test_method)
      return nil unless self.send(test_method)
      return true if just_test
      return self.send(coerce_method, params.dup)
    elsif respond_to?(coerce_method)
      return true if just_test
      return self.send(coerce_method, params.dup)
    else
      return nil
    end
  end
end
