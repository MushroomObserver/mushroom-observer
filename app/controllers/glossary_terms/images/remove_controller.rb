# frozen_string_literal: true

# NOTE: Move to new namespaced controllers
#
# Observations::Images::RemoveController#edit #update
# GlossaryTerms::Images::RemoveController#edit #update
# Move tests from images_controller_test
# No need to remove_images from Account profile: reuse_image removes image

module GlossaryTerms::Images
  class RemoveController < ApplicationController
    before_action :login_required
    before_action :pass_query_params
    before_action :disable_link_prefetching

    # Maybe use shared form (but there's nothing to the "form")
    # Form used to remove one or more images from an observation (not destroy!)
    # Linked from: observations/show
    # Inputs:
    #   params[:id]                  (observation)
    #   params[:selected][image_id]  (value of "yes" means delete)
    # Outputs: @observation
    # Redirects to observations/show.
    def new # remove_images
      @object = find_or_goto_index(GlossaryTerm, params[:id].to_s)
      return unless @object

      return if check_permission!(@object)

      redirect_with_query(glossary_term_path(@object.id))
    end

    def create
      @object = find_or_goto_index(GlossaryTerm, params[:id].to_s)
      return unless @object

      unless check_permission!(@object)
        return redirect_with_query(glossary_term_path(@object.id))
      end
      return unless (images = params[:selected])

      remove_images_from_object(images)
    end

    ############################################################################

    private

    def remove_images_from_object(images)
      images.each do |image_id, do_it|
        next unless do_it == "yes"

        next unless (image = Image.safe_find(image_id))

        @object.remove_image(image)
        image.log_remove_from(@object)
        flash_notice(:runtime_image_remove_success.t(id: image_id))
      end
      redirect_with_query(glossary_term_path(@object.id))
    end
  end
end
