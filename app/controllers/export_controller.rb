# frozen_string_literal: true

######### Exports
class ExportController < ApplicationController
  EXPORTABLE_MODELS = [Image, Location, LocationDescription, NameDescription,
                       Name].freeze

  before_action :login_required

  # Callback (no view) to let reviewers change the export status of an
  # Image, Name, Location or Description from the show pages.
  def set_export_status
    update_status(:export)
  end

  def set_ml_status
    update_status(:ml)
  end

  private

  def update_status(status_type)
    parse_params
    error = check_for_error
    return flash_redirect(error) if error

    obj = find_or_goto_index(@model_class, @id)
    return unless obj

    update_obj(obj, status_type)
    if params[:return]
      redirect_back_or_default("/")
    else
      controller = params[:return_controller] || obj.show_controller
      action = params[:return_action] || obj.show_action
      redirect_with_query(controller: controller,
                          action: action, id: @id)
    end
  end

  def update_obj(obj, status_type)
    if status_type == :ml
      obj.diagnostic = (@value == "1")
    else
      obj.ok_for_export = (@value == "1")
    end
    obj.save_without_our_callbacks
  end

  def parse_params
    pass_query_params
    @type = params[:type].to_s
    @value = params[:value].to_s
    @model_class = EXPORTABLE_MODELS.find { |m| m.name.downcase == @type }
    @id = params[:id].to_s
  end

  def check_for_error
    return :runtime_admin_only.t unless reviewer?
    return :runtime_invalid.t(type: '"type"', value: @type) unless @model_class
    return if @value.match?(/^[01]$/)

    :runtime_invalid.t(type: '"value"', value: @value)
  end

  def flash_redirect(error)
    flash_error(error)
    redirect_back_or_default("/")
  end
end
