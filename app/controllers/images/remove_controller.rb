# frozen_string_literal: true

module Images
  class RemoveController < ApplicationController
    before_action :login_required

    # NOTE: Move to new namespaced controllers
    #
    # Observations::ImagesController#edit #update
    # GlossaryTerms::ImagesController#edit #update
    # Move tests from images_controller_test
    # No need to remove_images from Account profile: reuse_image removes image

    # Form used to remove one or more images from an observation (not destroy!)
    # Linked from: observations/show
    # Inputs:
    #   params[:id]                  (observation)
    #   params[:selected][image_id]  (value of "yes" means delete)
    # Outputs: @observation
    # Redirects to observations/show.
    def remove_images
      remove_images_from_object(Observation, params)
    end

    def remove_images_for_glossary_term
      remove_images_from_object(GlossaryTerm, params)
    end

    ############################################################################

    private

    def remove_images_from_object(target_class, params)
      @object = find_or_goto_index(target_class, params[:id].to_s)
      return unless @object

      unless check_permission!(@object)
        return redirect_with_query(controller: target_class.show_controller,
                                   action: target_class.show_action,
                                   id: @object.id)
      end

      return unless request.method == "POST" && (images = params[:selected])

      create_removal(images, target_class)
    end

    def create_removal(images, target_class)
      images.each do |image_id, do_it|
        next unless do_it == "yes"

        next unless (image = Image.safe_find(image_id))

        @object.remove_image(image)
        image.log_remove_from(@object)
        flash_notice(:runtime_image_remove_success.t(id: image_id))
      end
      redirect_with_query(controller: target_class.show_controller,
                          action: target_class.show_action, id: @object.id)
    end
  end
end
