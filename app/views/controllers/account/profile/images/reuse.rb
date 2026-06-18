# frozen_string_literal: true

# Action template for `Account::Profile::ImagesController#reuse` —
# the "pick an existing image as your profile picture" page. Renders
# the shared `ImagesToReuseForm`.
module Views::Controllers::Account::Profile::Images
  class Reuse < Views::FullPageBase
    prop :user, ::User
    prop :objects, _Array(::Image)
    prop :pagination_data, ::PaginationData
    prop :all_users, _Boolean, default: false

    def view_template
      container_class(:full)
      add_page_title(:image_reuse_title.t(name: @user.legal_name))

      render(::Views::Controllers::Shared::ImagesToReuseForm.new(
               target: @user,
               user: @user,
               objects: @objects,
               pagination_data: @pagination_data,
               all_users: @all_users
             ))
    end
  end
end
