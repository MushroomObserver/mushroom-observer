# frozen_string_literal: true

# Action template for `Names::ClassificationController#edit`.
# Page-chrome + the `Names::Classification::Form` Phlex form.
class Views::Controllers::Names::Classification::Edit < Views::FullPageBase
  prop :name, ::Name

  def view_template
    add_page_title(
      :edit_classification_title.t(name: @name.display_name)
    )
    add_context_nav(Tab::Name::FormsReturn.new(name: @name))
    container_class(:text)

    render(Views::Controllers::Names::Classification::Form.new(@name))
  end
end
