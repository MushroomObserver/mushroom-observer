# frozen_string_literal: true

######### Exports
class ExportController < ApplicationController
  EXPORTABLE_MODELS = [Image, Location, LocationDescription, NameDescription,
                       Name].freeze

  before_action :login_required

  # Callback (no view) to let reviewers change the export status of an
  # Image, Name, Location or Description from the show pages.
  def set_export_status
    pass_query_params
    id    = params[:id].to_s
    type  = params[:type].to_s
    value = params[:value].to_s
    model_class = EXPORTABLE_MODELS.find { |m| m.name.downcase == type }

    if !reviewer?
      flash_error(:runtime_admin_only.t)
      redirect_back_or_default("/")
    elsif !model_class
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
