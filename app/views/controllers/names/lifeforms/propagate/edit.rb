# frozen_string_literal: true

# Action template for
# `Names::Lifeforms::PropagateController#edit`. Page-chrome +
# the `Names::Lifeforms::Propagate::Form` Phlex form.
class Views::Controllers::Names::Lifeforms::Propagate::Edit <
  Views::FullPageBase
  prop :name, ::Name

  def view_template
    add_page_title(
      :propagate_lifeform_title.t(name: @name.user_display_name(current_user))
    )
    add_context_nav(Tab::Name::FormsReturn.new(name: @name))
    container_class(:text_image)

    render(Views::Controllers::Names::Lifeforms::Propagate::Form.new(
             FormObject::PropagateLifeform.new, name: @name
           ))
  end
end
