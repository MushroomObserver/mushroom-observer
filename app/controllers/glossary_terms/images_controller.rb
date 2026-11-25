# frozen_string_literal: true

# Clicking on an image currently fires a GET to these actions... because it
# comes from a link made by Components::InteractiveImage(image_link: url_args)
# with CRUD refactor, change component link to fire a POST somehow?

module GlossaryTerms
  class ImagesController < ApplicationController
    before_action :login_required

    ############################################################################

    # rubocop:disable MO/NoLongCommentBlock
    # REMOVE IMAGES. These actions are more or less identical to the ones in
    # Observations::ImagesController. Each image tile has a button that's a
    # form used to remove one or more images from a glossary_term (not destroy!)
    # Linked from: glossary_terms/show
    # Inputs:
    #   params[:id]                  (glossary_term)
    #   params[:selected][image_id]  (value of "yes" means delete)
    # Outputs: @object
    # Redirects to glossary_terms/show.
    # remove_images. No permission check — `GlossaryTerm#can_edit?`
    # returns true for any logged-in user, and `login_required`
    # runs before this action.
    # rubocop:enable MO/NoLongCommentBlock
    def remove
      return unless (@object = find_or_goto_index(GlossaryTerm,
                                                  params[:id].to_s))

      render_remove_view
    end

    # The remove form submits to this action. Same permission note
    # as `#remove` above.
    def detach
      @object = find_or_goto_index(GlossaryTerm, params[:id].to_s)
      return unless @object
      return unless (images_data = params[:selected])

      detach_images_from_glossary_term(images_data)
    end

    ############################################################################

    private

    def detach_images_from_glossary_term(images_data)
      return rerender_remove_form_with_no_save_error if images_data == ""

      images_data.each do |image_id, do_it|
        next unless do_it == "yes"

        next unless (image = Image.safe_find(image_id))

        @object.remove_image(image)
        image.current_user = @user
        image.log_remove_from(@object)
        flash_notice(:runtime_image_remove_success.t(id: image_id))
      end
      redirect_to(glossary_term_path(@object.id))
    end

    def rerender_remove_form_with_no_save_error
      flash_error(:runtime_no_save.t(type: :glossary_term))
      render_remove_view_invalid(
        location: remove_images_from_glossary_term_path(params[:id])
      )
    end

    def render_remove_view(status: :ok, **render_opts)
      render(
        Views::Controllers::GlossaryTerms::Images::Remove.new(object: @object),
        status: status, **render_opts
      )
    end

    def render_remove_view_invalid(**)
      render_remove_view(**)
      self.status = :unprocessable_content
    end
  end
end
