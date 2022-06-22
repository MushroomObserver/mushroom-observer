# frozen_string_literal: true

# TODO: where does this stuff belong?
module ObserverController::Other
  # Callback to let reviewers change the export status of a Name from the
  # show_name page.
  def set_export_status
    pass_query_params
    id    = params[:id].to_s
    type  = params[:type].to_s
    value = params[:value].to_s
    model_class = type.camelize.safe_constantize
    if !reviewer?
      flash_error(:runtime_admin_only.t)
      redirect_back_or_default("/")
    elsif !model_class ||
          !model_class.respond_to?(:column_names) ||
          model_class.column_names.exclude?("ok_for_export")
      flash_error(:runtime_invalid.t(type: '"type"', value: type))
      redirect_back_or_default("/")
    elsif !value.match(/^[01]$/)
      flash_error(:runtime_invalid.t(type: '"value"', value: value))
      redirect_back_or_default("/")
    elsif (obj = find_or_goto_index(model_class, id))
      obj.ok_for_export = (value == "1")
      obj.save_without_our_callbacks
      if params[:return]
        redirect_back_or_default("/")
      else
        controller = params[:return_controller] || obj.show_controller
        action = params[:return_action] || obj.show_action
        redirect_with_query(controller: controller,
                            action: action, id: id)
      end
    end
  end
end
