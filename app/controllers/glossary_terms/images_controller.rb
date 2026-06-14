# frozen_string_literal: true

# Clicking on an image currently fires a GET to these actions... because it
# comes from a link made by Components::InteractiveImage(link: url_args)
# with CRUD refactor, change component link to fire a POST somehow?

module GlossaryTerms
  class ImagesController < ApplicationController
    include ::ImageReusable

    before_action :login_required

    # reuse_image_for_glossary_term
    def reuse
      return unless find_glossary_term!

      load_images_to_reuse
      render(Views::Controllers::GlossaryTerms::Images::Reuse.new(
               object: @object,
               user: @user,
               objects: @reuse_images,
               pagination_data: @reuse_pagination,
               all_users: @reuse_all_users
             ))
    end

    # reuse image form buttons POST here
    def attach
      return unless find_glossary_term!

      @img_id = params.dig(:image_reuse, :img_id).presence || params[:img_id]
      image = Image.safe_find(@img_id)
      return render_reuse_with_invalid_id_error unless image

      attach_image_to_glossary_term(image)
    end

    private

    ############################################################################

    # The actual grid of attachable images (partial) is a shared layout.
    # CRUD refactor makes each image link POST to create or edit.

    def find_glossary_term!
      @object = find_or_goto_index(GlossaryTerm, params[:id].to_s)
    end

    def render_reuse_with_invalid_id_error
      flash_error(:runtime_image_reuse_invalid_id.t(id: @img_id))
      render_reuse_page
    end

    def render_reuse_page
      load_images_to_reuse
      render(
        Views::Controllers::GlossaryTerms::Images::Reuse.new(
          object: @object, user: @user, objects: @reuse_images,
          pagination_data: @reuse_pagination, all_users: @reuse_all_users
        ),
        location: reuse_images_for_glossary_term_path(@object.id)
      )
    end

    def attach_image_to_glossary_term(image = nil)
      if image &&
         @object.add_image(image) &&
         @object.save
        image.log_reuse_for(@object)
        redirect_to(glossary_term_path(@object.id))
      else
        flash_error(:runtime_no_save.t(:glossary_term)) if image
        render_reuse_page
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
    # remove_images. No permission check — `GlossaryTerm#can_edit?`
    # returns true for any logged-in user, and `login_required`
    # runs before this action.
    def remove
      return unless (@object = find_or_goto_index(GlossaryTerm,
                                                  params[:id].to_s))

      render(Views::Controllers::GlossaryTerms::Images::Remove.new(
               object: @object
             ))
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
        image.log_remove_from(@object)
        flash_notice(:runtime_image_remove_success.t(id: image_id))
      end
      redirect_to(glossary_term_path(@object.id))
    end

    def rerender_remove_form_with_no_save_error
      flash_error(:runtime_no_save.t(:glossary_term))
      render(
        Views::Controllers::GlossaryTerms::Images::Remove.new(object: @object),
        location: remove_images_from_glossary_term_path(params[:id])
      )
    end
  end
end
