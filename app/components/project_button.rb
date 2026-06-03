# frozen_string_literal: true

# Shared button shape for the action-button rows rendered above
# project-scoped observation listings (on the observations index
# inside a project) and above species-list-scoped observation
# listings (on the species-list show page). Wraps
# `Components::CrudButton::Get` in btn-frame text-link mode with the
# `btn-lg` size + `my-3 mr-3` row spacing both consumers need.
class Components::ProjectButton < Components::Base
  prop :name, _Any
  prop :target, _Any

  def view_template
    render(Components::CrudButton::Get.new(
             name: @name,
             target: @target,
             btn: "btn btn-default",
             class: "btn-lg my-3 mr-3"
           ))
  end
end
