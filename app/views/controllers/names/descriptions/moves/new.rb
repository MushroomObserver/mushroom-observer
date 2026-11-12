# frozen_string_literal: true

# Action view for `names/descriptions/moves#new`. Sets the chrome and
# renders the moves form.
module Views::Controllers::Names::Descriptions::Moves
  class New < Views::FullPageBase
    prop :description, ::NameDescription
    prop :user, _Nilable(::User), default: nil

    def view_template
      add_page_title(:move_descriptions_title.t(
        object: @description.format_name
      ).small_author)
      add_context_nav(::Tab::NameDescription::FormPermissions.new(
                        description: @description
                      ))

      render(Form.new(@description, user: @user))
    end
  end
end
