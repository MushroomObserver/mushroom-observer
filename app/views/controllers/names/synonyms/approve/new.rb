# frozen_string_literal: true

# Action template for `Names::Synonyms::ApproveController#new`.
# Page-chrome + the `Names::Synonyms::Approve::Form` Phlex form.
class Views::Controllers::Names::Synonyms::Approve::New < Views::FullPageBase
  prop :name, ::Name
  # `Name#approved_synonyms` returns an Array of Names — the form
  # lists each as a candidate to approve.
  prop :approved_names, _Array(::Name), default: -> { [] }

  def view_template
    add_page_title(
      :name_approve_title.t(name: @name.display_name(current_user))
    )
    add_context_nav(Tab::Name::FormsReturn.new(name: @name))

    render(Views::Controllers::Names::Synonyms::Approve::Form.new(
             FormObject::ApproveSynonym.new(deprecate_others: true),
             name: @name, approved_names: @approved_names, user: current_user
           ))
  end
end
