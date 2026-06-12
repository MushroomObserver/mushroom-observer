# frozen_string_literal: true

# Action template for `GlossaryTerms::ImagesController#reuse` — the
# "attach an existing image to this glossary term" page. Sets the
# action-nav and renders the shared `ImagesToReuseForm`.
module Views::Controllers::GlossaryTerms::Images
  class Reuse < Views::Base
    prop :object, ::GlossaryTerm
    prop :user, _Nilable(::User), default: nil
    prop :objects, _Array(::Image)
    prop :pagination_data, ::PaginationData
    prop :all_users, _Boolean, default: false

    def view_template
      add_page_title(
        :image_reuse_title.t(name: @object.unique_format_name)
      )
      add_context_nav(::Tab::GlossaryTerm::ImageForm.new(term: @object))
      container_class(:full)

      render(::Views::Controllers::Shared::ImagesToReuseForm.new(
               target: @object,
               user: @user,
               objects: @objects,
               pagination_data: @pagination_data,
               all_users: @all_users
             ))
    end
  end
end
