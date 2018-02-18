#
#  = Extensions to ActionView::Helpers::FormBuilder
#
#  The FormBuilder mechanism is very handy, but Rails failed to give it a
#  complete complement of functionality.  This helps fix that short-coming.
#
#  == Instance Methods
#
#  hidden_field::     Add hidden field to form.
#
################################################################################

class ActionView::Helpers::FormBuilder
  def hidden_field(method, options = {})
    @template.hidden_field(@object_name, method, options.merge(object: @object))
  end
end
