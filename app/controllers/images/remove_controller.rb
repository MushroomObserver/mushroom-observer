# frozen_string_literal: true

module Images
  class RemoveController < ApplicationController
    before_action :login_required

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

    ##############################################################################

    private

    def remove_images_from_object(target_class, params)
      pass_query_params
      @object = find_or_goto_index(target_class, params[:id].to_s)
      return unless @object

      redirect_url = if target_class.controller_normalized?
                       send("#{target_class.to_s.underscore}_path",
                            @object.id)
                     else
                       { controller: target_class.show_controller,
                         action: target_class.show_action, id: @object.id }
                     end

      if check_permission!(@object)
        if request.method == "POST" && (images = params[:selected])
          images.each do |image_id, do_it|
            next unless do_it == "yes"

            next unless (image = Image.safe_find(image_id))

            @object.remove_image(image)
            image.log_remove_from(@object)
            flash_notice(:runtime_image_remove_success.t(id: image_id))
          end
          redirect_with_query(redirect_url)
        end
      else
        redirect_with_query(redirect_url)
      end
    end

    public

    ##############################################################################

    def remove_images_for_glossary_term
      remove_images_from_object(GlossaryTerm, params)
    end
  end
end
