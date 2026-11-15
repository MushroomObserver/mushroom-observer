# frozen_string_literal: true

# Action template for `Names::ClassificationController#edit`.
# Page-chrome + the `Names::Classification::Form` Phlex form.
class Views::Controllers::Names::Classification::Edit < Views::FullPageBase
  prop :name, ::Name

  def view_template
    add_title_with_name(:edit_classification_title, name: @name,
                                                    user: current_user)
    add_context_nav(Tab::Name::FormsReturn.new(name: @name))

    render(Views::Controllers::Names::Classification::Form.new(
             @name
           ))
  end
end
