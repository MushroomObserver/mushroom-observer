# frozen_string_literal: true

module Locations
  class DescriptionsController < ApplicationController
    include ::Descriptions
    include ::Locations::Descriptions::SharedPrivateMethods

    before_action :store_location, except: [:index, :destroy]
    before_action :pass_query_params, except: [:index]
    before_action :login_required
    before_action :require_successful_user, only: [
      :new, :create
    ]

    ############################################################################
    # INDEX
    #
    def index
      build_index_with_query
    end

    def controller_model_name
      "LocationDescription"
    end

    private

    # Is :name
    def default_sort_order
      ::Query::LocationDescriptions.default_order # :name
    end

    # Used by ApplicationController to dispatch #index to a private method
    def index_active_params
      [:by_author, :by_editor, :by, :q, :id].freeze
    end

    # Display list of location_descriptions that a given user is author on.
    def by_author
      user = find_obj_or_goto_index(
        model: User, obj_id: params[:by_author].to_s,
        index_path: location_descriptions_index_path
      )
      return unless user

      query = create_query(:LocationDescription, by_author: user)
      [query, {}]
    end

    # Display list of location_descriptions that a given user is editor on.
    def by_editor
      user = find_obj_or_goto_index(
        model: User, obj_id: params[:by_editor].to_s,
        index_path: location_descriptions_index_path
      )
      return unless user

      query = create_query(:LocationDescription, by_editor: user)
      [query, {}]
    end

    # Hook runs before template displayed. Must return query.
    def filtered_index_final_hook(query, _display_opts)
      store_query_in_session(query)
      query
    end

    def index_display_opts(opts, _query)
      { num_per_page: 50 }.merge(opts)
    end

    public

    ############################################################################

    def show
      return unless find_description!

      case params[:flow]
      when "next"
        redirect_to_next_object(:next, LocationDescription, params[:id].to_s)
      when "prev"
        redirect_to_next_object(:prev, LocationDescription, params[:id].to_s)
      end

      @location = @description.location
      return unless description_parent_exists?(@location)
      return unless user_has_permission_to_see_description?

      update_view_stats(@description)
      @canonical_url = description_canonical_url(@description)
      @projects = users_projects_which_dont_have_desc_of_this(@location)
      @versions = @description.versions
      @comments = @description.comments&.sort_by(&:created_at)&.reverse
    end

    def new
      find_location
      find_licenses
      @description = LocationDescription.new
      @description.location = @location

      # Render a blank form.
      initialize_description_source
    end

    def create
      find_location
      find_licenses
      @description = LocationDescription.new
      @description.location = @location

      # Render a blank form.
      initialize_description_source
      @description.attributes = permitted_location_description_params
      if @description.valid?
        save_new_description_flash_and_redirect
      else
        flash_object_errors(@description)
        render_new
      end
    end

    def edit
      return unless find_description!

      return unless check_description_edit_permission!

      find_description_parent
      find_licenses
    end

    def update
      return unless find_description!

      return unless check_description_edit_permission!

      find_description_parent
      find_licenses
      @description.attributes = permitted_location_description_params

      modify_description_permissions
      save_if_changes_made_or_flash
    end

    def destroy
      return unless find_description!

      check_delete_permission_flash_and_redirect
    end

    ############################################################################

    private

    def find_location
      @location = Location.find(params[:location_id].to_s)
    end

    def find_description_parent
      @location = Location.find(@description.parent_id.to_s)
    end

    def render_new
      render("new", location: new_location_description_path(@location.id))
    end

    def render_edit
      render("edit", location: edit_location_description_path(@location.id))
    end

    # called by :create
    def save_new_description_flash_and_redirect
      initialize_description_permissions
      @description.save

      log_description_created
      flash_notice(
        :runtime_location_description_success.t(id: @description.id)
      )
      redirect_to(@description.show_link_args)
    end

    # called by :update
    def save_if_changes_made_or_flash
      # No changes made.
      if !@description.changed?
        flash_warning(:runtime_edit_location_description_no_change.t)
        render_edit

      # Try to save and flash if there were error(s).
      elsif !@description.save
        flash_object_errors(@description)
        render_edit

      # Updated successfully.
      else
        flash_notice(
          :runtime_edit_location_description_success.t(id: @description.id)
        )
        log_description_updated
        resolve_merge_conflicts_and_delete_old_description
        redirect_to(@description.show_link_args)
      end
    end

    def permitted_location_description_params
      params.require(:description).
        permit(:source_type, :source_name, :project_id, :public_write, :public,
               :license_id, :gen_desc, :ecology, :species, :notes, :refs)
    end
  end
end
