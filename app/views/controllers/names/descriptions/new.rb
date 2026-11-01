# frozen_string_literal: true

# Action view for `names/descriptions#new`. Sets the chrome and
# renders the shared description form.
module Views::Controllers::Names::Descriptions
  class New < Views::FullPageBase
    prop :name, ::Name
    prop :description, ::NameDescription
    prop :user, _Nilable(::User), default: nil
    prop :licenses, _Array(_Tuple(String, Integer)), default: -> { [] }
    prop :project, _Nilable(::Project), default: nil
    prop :project_chosen, _Boolean, default: false

    def view_template
      add_page_title(:create_name_description_title.t(
                       name: @name.display_name(@user)
                     ))
      add_context_nav(::Tab::NameDescription::FormNew.new(
                        description: @description
                      ))

      draft_form = Components::Description::NewDraftForm.new(
        target: @name, project: @project, project_chosen: @project_chosen
      )
      render(draft_form)
      hr if draft_form.render?
      render(Views::Controllers::Descriptions::Form.new(
               @description, licenses: @licenses, user: @user, turbo: true
             ))
    end
  end
end
