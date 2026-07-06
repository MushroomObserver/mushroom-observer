# frozen_string_literal: true

# Action template for `Names::LifeformsController#edit`.
# Page-chrome + the `Names::Lifeforms::Form` Phlex form (which
# builds its own `FormObject::Lifeform` from the supplied Name).
class Views::Controllers::Names::Lifeforms::Edit < Views::FullPageBase
  prop :name, ::Name

  def view_template
    add_page_title(
      :edit_lifeform_title.t(name: @name.user_display_name(current_user))
    )
    add_context_nav(Tab::Name::FormsReturn.new(name: @name))
    container_class(:text_image)

    render(Views::Controllers::Names::Lifeforms::Form.new(
             FormObject::Lifeform.from_name(@name), name: @name
           ))
  end
end
