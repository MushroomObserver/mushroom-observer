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
#
# @example from a Tab PORO -- the generic "Add" default doesn't apply;
#   # the tab's own title is used unless name: is also given.
#   render(Components::Link::New.new(
#     tab: Tab::Observation::AddToSpeciesList.new(observation: @obs)
#   ))
class Components::Link::New < Components::Link::Get
  def initialize(target: nil, tab: nil, name: nil, icon: :add, **)
    name ||= :add.ti unless tab
    super(target: target, tab: tab, name: name, action: :new, icon: icon, **)
  end
end
