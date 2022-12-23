# frozen_string_literal: true

# Clicking on an image currently fires a GET to these actions... because it
# comes from a link made by thumbnail_helper#thumbnail(link: url_args)
# with CRUD refactor, change thumbnail helper to fire a POST somehow?

module GlossaryTerms
  class ImagesController < ApplicationController
    before_action :login_required

    before_action :login_required
    before_action :pass_query_params
    before_action :disable_link_prefetching

    # reuse_image_for_glossary_term
    def new
      @object = GlossaryTerm.safe_find(params[:id])

      serve_image_reuse_selections(params)
    end

    def create
      @object = GlossaryTerm.safe_find(params[:id])

      image = Image.safe_find(params[:img_id])
      unless image
        flash_error(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
        return serve_image_reuse_selections(params)
      end

      reuse_image_for_glossary_term(image)
    end

    private

    ############################################################################

    # The actual grid of images (partial) is basically a shared layout.
    # CRUD refactor makes each image link POST to create or edit.
    #
    def serve_image_reuse_selections(params)
      # params[:all_users] is a query param for rendering form images (possible
      # selections), not a form param for the submit.
      # It's toggled by a button on the page "Include other users' images"
      # that reloads the page with this param on or off

      # These could be set (except @objects) on shared layout
      if params[:all_users] == "1"
        @all_users = true
        query = create_query(:Image, :all, by: :updated_at)
      else
        query = create_query(:Image, :by_user, user: @user, by: :updated_at)
      end
      @layout = calc_layout_params
      @pages = paginate_numbers(:page, @layout["count"])
      @objects = query.paginate(@pages,
                                include: [:user, { observations: :name }])
    end

    def reuse_image_for_glossary_term(image = nil)
      if image &&
         @object.add_image(image) &&
         @object.save
        image.log_reuse_for(@object)
        redirect_with_query(glossary_term_path(@object.id))
      else
        flash_error(:runtime_no_save.t(:glossary_term)) if image
        serve_reuse_form(params)
      end
    end

    public

    ############################################################################

    # REMOVE IMAGES. These actions are more or less identical to the ones in
    # Observations::ImagesController. Each image tile has a button that's a
    # form used to remove one or more images from a glossary_term (not destroy!)
    # Linked from: glossary_terms/show
    # Inputs:
    #   params[:obj_id]              (glossary_term)
    #   params[:selected][image_id]  (value of "yes" means delete)
    # Outputs: @object
    # Redirects to glossary_term/show.
    # remove_images
    def edit
      @object = find_or_goto_index(GlossaryTerm, params[:id].to_s)
      return unless @object

      return if check_permission!(@object)

      redirect_with_query(glossary_term_path(@object.id))
    end

    def update
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
