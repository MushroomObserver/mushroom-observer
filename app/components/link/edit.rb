# frozen_string_literal: true

# GET link to the edit route of a model. Defaults to an edit icon and
# the generic "Edit <type>" label. Source of truth for edit links;
# `Components::Button::Edit` delegates here.
#
# @example standard edit link
#   render(Components::Link::Edit.new(target: @herbarium))
#
# @example outline button style
#   render(Components::Link::Edit.new(target: @herbarium, variant: :outline))
#
# @example bare icon
#   render(Components::Link::Edit.new(target: @herbarium, variant: :strip))
class Components::Link::Edit < Components::Link::Get
  def initialize(target:, name: nil, icon: :edit, **)
    super(target: target,
          name: name || default_name(target),
          action: :edit,
          icon: icon,
          **)
  end

  private

  def default_name(target)
    if target.is_a?(String) || target.is_a?(Hash)
      :edit.ti
    else
      :edit_object.t(type: target.type_tag)
    end
  end
end
