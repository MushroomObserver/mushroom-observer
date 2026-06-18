# frozen_string_literal: true

module Views::Controllers::GlossaryTerms
  module Images
    # Wrap of `GlossaryTerms::Images::RemoveForm`. Converted from
    # `glossary_terms/images/remove.html.erb`.
    class Remove < Views::FullPageBase
      prop :object, ::GlossaryTerm

      def view_template
        add_page_title(
          :image_remove_title.t(name: @object.unique_format_name)
        )
        add_context_nav(::Tab::GlossaryTerm::ImageForm.new(term: @object))
        container_class(:full)

        render(RemoveForm.new(
                 @object,
                 form_action:
                   detach_image_from_glossary_term_path(@object.id),
                 user: current_user
               ))
      end
    end
  end
end
