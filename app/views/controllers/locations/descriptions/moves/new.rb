# frozen_string_literal: true

module Views::Controllers::Locations::Descriptions::Moves
  class New < Views::FullPageBase
    prop :description, ::LocationDescription
    prop :user, _Nilable(::User), default: nil

    def view_template
      add_page_title(:merge_descriptions_title.t(
                       object: @description.format_name
                     ))
      add_context_nav(::Tab::LocationDescription::FormPermissions.new(
                        description: @description
                      ))

      render(Views::Controllers::Descriptions::Moves::Form.new(
               @description, user: @user
             ))
    end
  end
end
