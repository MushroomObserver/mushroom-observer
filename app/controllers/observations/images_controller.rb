# frozen_string_literal: true

# Clicking on an image currently fires a GET to these actions... because it
# comes from a link made by ImageHelper#interactive_image(link: url_args)
# with CRUD refactor, change ImageHelper helper to fire a POST somehow?

module Observations
  # Upload, attach, detach, edit Observation Images
  class ImagesController < ApplicationController
    before_action :login_required
    before_action :pass_query_params

    # NEW: Upload Images to an Observation.
    # was ImageController#add_image
    def new
      return unless (@observation = find_observation!)

      return unless check_observation_permission!

      @image = rough_cut_image
      @licenses = current_license_names_and_ids
      init_project_vars_for_add_or_edit(@observation)
    end

    # new (upload) image commits here
    def create
      return unless (@observation = find_observation!)

      return unless check_observation_permission!

      create_image
    end

    private

    def find_observation!
      find_or_goto_index(Observation, params[:id].to_s)
    end

    def check_observation_permission!
      return true if check_permission!(@observation)

      redirect_with_query(permanent_observation_path(id: @observation.id))
      false
    end

    def init_project_vars_for_add_or_edit(obs_or_img)
      @projects = User.current.projects_member(order: :title,
                                               include: :user_group)
      @project_checks = {}
      obs_or_img.projects.each do |proj|
        @projects << proj unless @projects.include?(proj)
        @project_checks[proj.id] = true
      end
    end

    def current_license_names_and_ids
      License.current_names_and_ids(@image.license)
    end

    def rough_cut_image
      @image = Image.new
      @image.license = @user.license
      @image.copyright_holder = @user.legal_name
      @image.user = @user
      # Set the default date to the date of the observation
      # Don't know how to correctly test this.
      @image.when = @observation.when
      @image
    end

    def create_image
      if params[:upload].blank?
        flash_warning(:runtime_no_changes.t)
      else
        # There are five upload spots on the form.
        # For as many as have an image, process the image.
        args = params[:image]
        i = 1
        while i < 5 || params[:upload]["image#{i}"].present?
          process_image(args, params[:upload]["image#{i}"])
          i += 1
        end
      end
      redirect_with_query(permanent_observation_path(id: @observation.id))
    end

    def process_image(args, upload)
      return if upload.blank?

      @image = Image.new(args.permit(permitted_image_args))
      @image.created_at = Time.current
      @image.updated_at = @image.created_at
      @image.user       = @user
      @image.image      = upload
      @image.save

      # The 1st save (or !save) puts the image's original filename in the db,
      # whether or not the user wants it.  So if we don't want it,
      # we must empty it and save a 2nd time.
      @image.original_name = "" if @user.keep_filenames == "toss"
      return flash_object_errors(@image) unless @image.save

      return revert_image_name_and_flash_errors unless
        @image.process_image(strip: @observation.gps_hidden)

      add_image_to_observation!
    end

    def add_image_to_observation!
      @observation.add_image(@image)
      @image.log_create_for(@observation)
      name = @image.original_name
      name = "##{@image.id}" if name.empty?
      flash_notice(:runtime_image_uploaded_image.t(name: name))
      update_related_projects(@image, params[:project])
    end

    def revert_image_name_and_flash_errors
      name = @image.original_name
      name = "???" if name.empty?
      flash_error(:runtime_image_invalid_image.t(name: name))
      flash_object_errors(@image)
    end

    def update_related_projects(img, checks)
      return false unless checks

      # Here's the problem: User can add image to obs he doesn't own
      # if it is attached to one of his projects.
      # Observation can be attached to other projects, too,
      # though, including ones the user isn't a member of.
      # We want the image to be attached even to these projects by default,
      # however we want to give the user the ability NOT to attach his images
      # to these projects which he doesn't belong to.
      # This means we need to consider checkboxes not only of  user's projects,
      # but also all  projects of the observation, as well.  Once it is detached
      # from one of these projects the user isn't on,
      # the checkbox will no longer show
      # up on the edit_image form, preventing a user from attaching images to
      # projects she doesn't belong to...
      # except in the very strict case of uploading images for
      # an observation which belongs to a project he doesn't belong to.
      projects = @user.projects_member
      img.observations.each do |obs|
        obs.projects.each do |project|
          projects << project unless projects.include?(project)
        end
      end

      attach_images_to_projects_and_flash_notices(img, projects, checks)
    end

    # Returns true if any changes made, false if none
    def attach_images_to_projects_and_flash_notices(img, projects, checks)
      any_changes = false
      projects.each do |project|
        before = img.projects.include?(project)
        after = checks["id_#{project.id}"] == "1"
        next if before == after

        if after
          project.add_image(img)
          flash_notice(:attached_to_project.t(object: :image,
                                              project: project.title))
        else
          project.remove_image(img)
          flash_notice(:removed_from_project.t(object: :image,
                                               project: project.title))
        end
        any_changes = true
      end
      any_changes
    end

    public

    ###########################################################################

    # Form for editing date/license/notes on an observation image.
    # Linked from: show_image/original
    # Inputs: params[:id] (image)
    #   params[:comment][:summary]
    #   params[:comment][:comment]
    # Outputs: @image, @licenses
    def edit
      return unless (@image = find_image!)

      @licenses = current_license_names_and_ids
      check_image_permission!
      init_project_vars_for_add_or_edit(@image)
    end

    def update
      return unless (@image = find_image!)

      @licenses = current_license_names_and_ids
      check_image_permission!

      @image.attributes = permitted_image_params

      if image_or_projects_updated
        # redirect_with_query(image_path(@image.id))
        render("images/show",
               location: image_path(@image.id, q: get_query_param))
      else
        init_project_vars_for_reload(@image)
        render(:edit, location: edit_image_path(@image.id))
      end
    end

    private

    def find_image!
      find_or_goto_index(Image, params[:id].to_s)
    end

    def check_image_permission!
      return if check_permission!(@image)

      redirect_with_query(image_path(@image))
    end

    def permitted_image_params
      params.require(:image).permit(permitted_image_args)
    end

    def image_or_projects_updated
      if !image_data_changed?
        update_projects_and_flash_notice!
        true
      elsif !@image.save
        flash_object_errors(@image)
        false
      else
        @image.log_update
        flash_notice(:runtime_image_edit_success.t(id: @image.id))
        update_related_projects(@image, params[:project])
        true
      end
    end

    def image_data_changed?
      @image.when_changed? ||
        @image.notes_changed? ||
        @image.copyright_holder_changed? ||
        @image.original_name_changed? ||
        @image.license_id_changed?
    end

    def update_projects_and_flash_notice!
      if update_related_projects(@image, params[:project])
        flash_notice(:runtime_image_edit_success.t(id: @image.id))
      else
        flash_notice(:runtime_no_changes.t)
      end
    end

    def init_project_vars_for_reload(obs_or_img)
      # (Note: In practice, this is never called for add_image,
      # so obs_or_img is always an image.)
      @projects = User.current.projects_member(order: :title,
                                               include: :user_group)
      @project_checks = {}
      obs_or_img.projects.each do |proj|
        @projects << proj unless @projects.include?(proj)
      end
      @projects.each do |proj|
        @project_checks[proj.id] =
          param_lookup([:project, "id_#{proj.id}"]) == "1"
      end
    end

    public

    ############################################################################

    # REUSE: Attach an Image to an Observation from existing uploads
    def reuse
      return unless (@observation = find_observation!)

      nil unless check_observation_permission!
    end

    # reuse image form buttons POST here
    def attach
      return unless (@observation = find_observation!)

      return unless check_observation_permission!

      image = Image.safe_find(params[:img_id])
      unless image
        flash_error(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
        # redirect_to(:reuse) and return
        render(:reuse,
               location: reuse_images_for_observation_path(@observation.id))
        return
      end

      attach_image_to_observation(image)
    end

    private

    # Attach an image to observation.
    def attach_image_to_observation(image)
      @observation.add_image(image)
      image.log_reuse_for(@observation)
      if @observation.gps_hidden
        error = image.strip_gps!
        flash_error(:runtime_failed_to_strip_gps.t(msg: error)) if error
      end
      redirect_with_query(permanent_observation_path(id: @observation.id))
      # render("observations/show",
      #        location: permanent_observation_path(id: @observation.id,
      #                                             q: get_query_param))
    end

    public

    ############################################################################

    # REMOVE IMAGES: Uses shared partial "shared/images_to_remove"
    # Form used to remove one or more images from an observation (not destroy!)
    # Linked from: observations/show
    # Inputs:
    #   params[:obj_id]              (observation)
    #   params[:selected][image_id]  (value of "yes" means remove)
    # Outputs: @observation
    # Redirects to observations/show.
    # remove_images
    def remove
      @object = find_or_goto_index(Observation, params[:id].to_s)
      return unless @object

      return if check_permission!(@object)

      redirect_with_query(permanent_observation_path(@object.id))
    end

    # Callback to DETACH images from an observation, form :put commits here
    def detach
      @object = find_or_goto_index(Observation, params[:id].to_s)
      return unless @object

      unless check_permission!(@object)
        return redirect_with_query(permanent_observation_path(@object.id))
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
      redirect_with_query(permanent_observation_path(@object.id))
    end
  end
end
