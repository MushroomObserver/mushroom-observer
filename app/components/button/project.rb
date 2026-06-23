# frozen_string_literal: true

# Shared button shape for the action-button rows rendered above
# project-scoped observation listings (on the observations index
# inside a project) and above species-list-scoped observation
# listings (on the species-list show page). Wraps
# `Components::CRUDButton::Get` in btn-frame text-link mode with the
# `btn-lg` size + `my-3 mr-3` row spacing both consumers need.
class Components::Button::Project < Components::Base
  prop :name, String
  # Anything `link_to`-like accepts: a URL string, a `[controller,
  # action, params...]` hash, or a model the route helper can resolve.
  prop :target, _Union(String, Hash, ::AbstractModel)

  def view_template
    render(Components::CRUDButton::Get.new(
             name: @name,
             target: @target,
             btn: "btn btn-default",
             class: "btn-lg my-3 mr-3"
           ))
  end
end
