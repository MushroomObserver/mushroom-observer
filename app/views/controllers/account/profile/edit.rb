# frozen_string_literal: true

# Action template for `Account::ProfileController#edit` — the user's
# profile edit page. Two columns: the `Form` on the left (name,
# location, notes, image upload, mailing address), the user's
# current profile image plus a remove button on the right.
#
module Views::Controllers::Account::Profile
  class Edit < Views::FullPageBase
    prop :user, ::User
    prop :copyright_holder, _Nilable(String)
    prop :copyright_year, Integer
    prop :licenses, _Array(Array)
    prop :upload_license_id, _Nilable(Integer)

    def view_template
      container_class(:full)
      add_page_title(:profile_title.t)
      add_context_nav(Tab::Account::ProfileEditActions.new)

      div(class: "row") do
        Column(xs: 12, sm: 7) { render_form }
        Column(xs: 12, sm: 5, class: "text-center") { render_image_column }
      end
    end

    private

    def render_form
      render(Form.new(
               @user,
               copyright_holder: @copyright_holder,
               copyright_year: @copyright_year,
               licenses: @licenses,
               upload_license_id: @upload_license_id
             ))
    end

    def render_image_column
      return unless @user.image

      render(Components::Image::Interactive.new(
               user: @user, image: @user.image, votes: false
             ))
      Button(
        type: :put,
        variant: :strip,
        name: :profile_image_remove.t,
        target: account_profile_remove_image_path,
        confirm: :are_you_sure.l
      )
    end
  end
end
