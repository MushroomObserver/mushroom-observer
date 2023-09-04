# frozen_string_literal: true

# Clicking on an image currently fires a GET to these actions... because it
# comes from a link made by thumbnail_helper#interactive_image(link: url_args)
# with CRUD refactor, change thumbnail helper to fire a POST somehow?

module GlossaryTerms
  class ImagesController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    # reuse_image_for_glossary_term
    def reuse
      @object = GlossaryTerm.safe_find(params[:id])
    end

    # reuse image form buttons POST here
    def attach
      @object = GlossaryTerm.safe_find(params[:id])

      image = Image.safe_find(params[:img_id])
      unless image
        flash_error(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
        render(:reuse,
               location: reuse_images_for_glossary_term_path(params[:img_id]))
        return
      end

      attach_image_to_glossary_term(image)
    end

    private

    ############################################################################

    # The actual grid of attachable images (partial) is a shared layout.
    # CRUD refactor makes each image link POST to create or edit.

    def attach_image_to_glossary_term(image = nil)
      if image &&
         @object.add_image(image) &&
         @object.save
        image.log_reuse_for(@object)
        redirect_with_query(glossary_term_path(@object.id))
      else
        flash_error(:runtime_no_save.t(:glossary_term)) if image
        render(:reuse,
               location: reuse_images_for_glossary_term_path(params[:img_id]))
      end
    end

    public

    ############################################################################

    # REMOVE IMAGES. These actions are more or less identical to the ones in
    # Observations::ImagesController. Each image tile has a button that's a
    # form used to remove one or more images from a glossary_term (not destroy!)
    # Linked from: glossary_terms/show
    # Inputs:
    #   params[:id]                  (glossary_term)
    #   params[:selected][image_id]  (value of "yes" means delete)
    # Outputs: @object
    # Redirects to glossary_terms/show.
    # remove_images
    def remove
      @object = find_or_goto_index(GlossaryTerm, params[:id].to_s)
      return unless @object

      return if check_permission!(@object)

      redirect_with_query(glossary_term_path(@object.id))
    end

    # The remove form submits to this action
    def detach
      @object = find_or_goto_index(GlossaryTerm, params[:id].to_s)
      return unless @object

      unless check_permission!(@object)
        return redirect_with_query(glossary_term_path(@object.id))
      end

      return unless (images_data = params[:selected])

      detach_images_from_glossary_term(images_data)
    end

    ############################################################################

    private

    def detach_images_from_glossary_term(images_data)
      if images_data == ""
        flash_error(:runtime_no_save.t(:glossary_term))
        return render(:remove,
                      location: remove_images_from_glossary_term_path(
                        params[:id]
                      ))
      end

      images_data.each do |image_id, do_it|
        next unless do_it == "yes"

        next unless (image = Image.safe_find(image_id))

        @object.remove_image(image)
        image.log_remove_from(@object)
        flash_notice(:runtime_image_remove_success.t(id: image_id))
      end
      redirect_with_query(glossary_term_path(@object.id))
      # render("glossary_terms/show",
      #        location: glossary_term_path(@object.id, q: get_query_param))
    end
  end
end
