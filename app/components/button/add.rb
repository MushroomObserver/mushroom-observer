# frozen_string_literal: true

# Green "+ Add" button: `:add` icon, `btn-success`, `sm`, a
# responsive "Add" label, the `new_object_button` selector class, and
# a tooltip/aria-label naming the current controller's model ("New
# Observation"). Pass `modal_id:` to open a modal instead of
# navigating to `target:`. Omit `target:` (with no `modal_id:`) to
# default to the current controller's `:new` action.
#
# @example Rubric "+ Add" (defaults target: to this controller's :new)
#   Button(type: :add)
#
# @example Modal trigger
#   Button(type: :add,
#     target: new_project_alias_path(project_id: @project.id),
#     modal_id: "project_alias")
class Components::Button::Add < Components::Base
  prop :modal_id, _Nilable(String), default: nil
  prop :target, _Nilable(String), default: nil
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template
    if @modal_id
      render(Components::Button::ModalToggle.new(
               modal_id: @modal_id, target: @target, icon: :add,
               **button_opts
             ))
    else
      render(Components::Button::New.new(
               target: @target || default_new_target, **button_opts
             ))
    end
  end

  private

  def button_opts
    full_label = new_object_label
    mix({
          name: :add.ti, show_label: :responsive,
          variant: :success, size: :sm,
          title: full_label, aria: { label: full_label },
          data: { tooltip_target: "tip", placement: :bottom },
          class: "new_object_button ml-1 mr-0 mx-sm-3"
        }, @attributes)
  end

  def new_object_label
    obj_name = controller.controller_model_name.underscore.to_sym.ti
    [:new.ti, obj_name].safe_join(" ")
  end

  def default_new_target
    url_for(controller: "/#{controller_path}", action: :new)
  end
end
