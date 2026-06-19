# frozen_string_literal: true

# Action template for `Observations::ImagesController#reuse` — the
# "attach an existing image to this observation" page. Sets the
# action-nav and renders the shared `ImagesToReuseForm`.
module Views::Controllers::Observations::Images
  class Reuse < Views::FullPageBase
    prop :observation, ::Observation
    prop :user, _Nilable(::User), default: nil
    prop :objects, _Array(::Image)
    prop :pagination_data, ::PaginationData
    prop :all_users, _Boolean, default: false

    def view_template
      add_page_title(
        :image_reuse_title.t(name: @observation.unique_format_name)
      )
      add_context_nav(
        ::Tab::Observation::ImagesReuse.new(observation: @observation)
      )
      container_class(:full)

      render(::Views::Controllers::Shared::ImagesToReuseForm.new(
               target: @observation,
               user: @user,
               objects: @objects,
               pagination_data: @pagination_data,
               all_users: @all_users
             ))
    end
  end
end
