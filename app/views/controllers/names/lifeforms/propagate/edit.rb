# frozen_string_literal: true

# Action template for
# `Names::Lifeforms::PropagateController#edit`. Page-chrome +
# the `Names::Lifeforms::Propagate::Form` Phlex form.
class Views::Controllers::Names::Lifeforms::Propagate::Edit <
  Views::Base
  prop :name, ::Name

  def view_template
    add_page_title(
      :propagate_lifeform_title.t(name: @name.display_name)
    )
    add_context_nav(Tab::Name::FormsReturn.new(name: @name))
    container_class(:text_image)

    render(Views::Controllers::Names::Lifeforms::Propagate::Form.new(
             FormObject::PropagateLifeform.new, name: @name
           ))
  end
end
