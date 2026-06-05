# frozen_string_literal: true

# Action view for `names/descriptions/merges#new`. Sets the chrome and
# renders the shared merges form.
module Views::Controllers::Names::Descriptions::Merges
  class New < Views::Base
    prop :description, ::NameDescription
    prop :user, _Nilable(::User), default: nil

    def view_template
      add_page_title(:merge_descriptions_title.t(
                       object: @description.format_name
                     ))
      add_context_nav(::Tab::NameDescription::FormPermissions.new(
                        description: @description
                      ))

      render(Views::Controllers::Descriptions::Merges::Form.new(
               @description, user: @user
             ))
    end
  end
end
