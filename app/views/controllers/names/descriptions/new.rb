# frozen_string_literal: true

# Action view for `names/descriptions#new`. Sets the chrome and
# renders the shared description form.
module Views::Controllers::Names::Descriptions
  class New < Views::FullPageBase
    prop :name, ::Name
    prop :description, ::NameDescription
    prop :user, _Nilable(::User), default: nil
    prop :licenses, _Array(_Tuple(String, Integer)), default: -> { [] }

    def view_template
      add_page_title(:create_name_description_title.t(
                       name: @name.user_display_name(@user)
                     ))
      add_context_nav(::Tab::NameDescription::FormNew.new(
                        description: @description
                      ))

      render(Views::Controllers::Descriptions::Form.new(
               @description, licenses: @licenses, user: @user
             ))
    end
  end
end
