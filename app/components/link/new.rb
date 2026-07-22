# frozen_string_literal: true

# GET link to the new-form route. Defaults to an add icon and the
# generic "Add" label. Source of truth for new-form links;
# `Components::Button::New` delegates here.
#
# @example
#   render(Components::Link::New.new(
#     target: new_herbarium_path,
#     name: :new_object.t(type: :herbarium)
#   ))
class Components::Link::New < Components::Link::Get
  def initialize(target:, name: nil, icon: :add, **)
    super(target: target,
          name: name || :add.ti,
          action: :new,
          icon: icon,
          **)
  end
end
