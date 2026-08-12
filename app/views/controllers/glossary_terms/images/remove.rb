# frozen_string_literal: true

module Views::Controllers::GlossaryTerms
  module Images
    # Wrap of `GlossaryTerms::Images::RemoveForm`.
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
                 user: current_user
               ))
      end
    end
  end
end
