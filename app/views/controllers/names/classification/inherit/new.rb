# frozen_string_literal: true

# Action template for
# `Names::Classification::InheritController#new`. Page-chrome +
# the `Names::Classification::Inherit::Form` Phlex form.
class Views::Controllers::Names::Classification::Inherit::New <
  Views::FullPageBase
  prop :name, ::Name
  prop :parent_text_name, _Nilable(String), default: nil
  # `@candidates` carries the ambiguous-parent disambiguation list —
  # an Array of `::Name` candidates when the user's
  # `parent_text_name` matched multiple Names.
  prop :candidates, _Nilable(_Array(::Name)), default: nil
  # The controller passes a translation key Symbol (e.g.
  # `:inherit_classification_alt_spellings`) and the form
  # localizes it for display.
  prop :message, _Nilable(Symbol), default: nil

  def view_template
    add_page_title(
      :inherit_classification_title.t(
        name: @name.display_name(current_user)
      )
    )
    add_context_nav(Tab::Name::FormsReturn.new(name: @name))
    container_class(:text)

    render(Views::Controllers::Names::Classification::Inherit::Form.new(
             name: @name, parent: @parent_text_name,
             candidates: @candidates, message: @message, user: current_user
           ))
  end
end
