# frozen_string_literal: true

# Shared path-building logic for link and form-button CRUD components.
# Included by `Components::Link::Get` (GET links) and
# `Components::Button::CRUDBase` (mutation form-buttons).
#
# Expects the includer to expose `@target`, `@action`, `@back`,
# `@method`, and `@params` ivars, plus the controller helpers
# `controller_name` and `action_name`.
module Components::CRUDPathBuilding
  # Actions that map to a Rails named-route prefix — e.g. :edit →
  # `edit_<model>_path`.
  NAMED_ROUTE_ACTIONS = [:edit, :new, :download].freeze

  # Controllers whose edit/destroy actions support the `?back=`
  # round-trip so the controller can redirect after a mutation.
  SHOW_OBS_EDITABLES = %w[
    collection_numbers herbarium_records sequences external_links
  ].freeze

  private

  def path
    if @target.is_a?(String) || @target.is_a?(Hash)
      @target
    else
      target_path
    end
  end

  def identifier
    if @target.is_a?(String) || @target.is_a?(Hash)
      ""
    else
      "#{action}_#{@target.type_tag}_link_#{@target.id}"
    end
  end

  def action
    @action || @method
  end

  def target_path
    send(:"#{path_prefix}#{@target.type_tag}_path",
         @target.id, **path_args)
  end

  def path_args
    back = @back || default_back_param
    back ? { back: back } : {}
  end

  def default_back_param
    return nil unless back_eligible?
    return nil unless SHOW_OBS_EDITABLES.include?(controller_name)

    case action_name
    when "show" then :show
    when "index" then :index
    end
  end

  def back_eligible?
    [:edit, :destroy].include?(@action) &&
      !@target.is_a?(String) && !@target.is_a?(Hash)
  end

  def path_prefix
    NAMED_ROUTE_ACTIONS.include?(@action) ? "#{action}_" : ""
  end
end
