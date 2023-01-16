# frozen_string_literal: true

#   :index_location_description
#   :list_location_descriptions
#   :location_descriptions_by_author
#   :location_descriptions_by_editor
#   :show_location_description
#   :next_location_description
#   :prev_location_description
#   :show_past_location_description
#   :create_location_description
#   :edit_location_description
#   :destroy_location_description

module Locations
  class DescriptionsController < ApplicationController
    include ::Descriptions
    include ::Locations::Descriptions::SharedPrivateMethods

    before_action :store_location, except: [:index, :destroy]
    before_action :pass_query_params, except: [:index]
    before_action :login_required
    before_action :disable_link_prefetching, except: [
      :new, :create, :edit, :update, :show
    ]
    before_action :require_successful_user, only: [
      :new, :create
    ]

    ############################################################################
    #
    #  :section: Description Searches and Indexes
    #
    ############################################################################

    def index
      if params[:by_author].present?
        location_descriptions_by_author
      elsif params[:by_editor].present?
        location_descriptions_by_editor
      elsif params[:by].present? || params[:q].present? || params[:id].present?
        index_location_description
      else
        list_location_descriptions
      end
    end

    private

    # Displays a list of selected locations, based on current Query.
    def index_location_description
      query = find_or_create_query(:LocationDescription, by: params[:by])
      show_selected_location_descriptions(query, id: params[:id].to_s,
                                                 always_index: true)
    end

    # Displays a list of all location_descriptions.
    def list_location_descriptions
      query = create_query(:LocationDescription, :all, by: :name)
      show_selected_location_descriptions(query)
    end

    # Display list of location_descriptions that a given user is author on.
    def location_descriptions_by_author
      user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
      return unless user

      query = create_query(:LocationDescription, :by_author, user: user)
      show_selected_location_descriptions(query)
    end

    # Display list of location_descriptions that a given user is editor on.
    def location_descriptions_by_editor
      user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
      return unless user

      query = create_query(:LocationDescription, :by_editor, user: user)
      show_selected_location_descriptions(query)
    end

    # Show selected search results as a list with 'list_locations' template.
    def show_selected_location_descriptions(query, args = {})
      store_query_in_session(query)
      @links ||= []
      args = {
        controller: "/locations/descriptions",
        action: :index,
        num_per_page: 50
      }.merge(args)

      # Add some alternate sorting criteria.
      args[:sorting_links] = [
        ["name",        :sort_by_name.t],
        ["created_at",  :sort_by_created_at.t],
        ["updated_at",  :sort_by_updated_at.t],
        ["num_views",   :sort_by_num_views.t]
      ]

      # Add "show locations" link if this query can be coerced into an
      # observation query.
      @links << coerced_query_link(query, Location)

      show_index_of_objects(query, args)
    end

    public

    # --------------------------------------------------------------------------

    # Show just a LocationDescription.
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
    end

    def new
      find_location
      find_licenses
      @description = LocationDescription.new
      @description.location = @location

      # Render a blank form.
      initialize_description_source
    end

    # Create new description.
    def create
      find_location
      find_licenses
      @description = LocationDescription.new
      @description.location = @location

      # Render a blank form.
      initialize_description_source
      @description.attributes = allowed_location_description_params
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
      @description.attributes = allowed_location_description_params

      modify_description_permissions
      save_if_changes_made_or_flash
    end

    def destroy
      pass_query_params
      return unless find_description!

      check_delete_permission_flash_and_redirect
    end

    private

    def find_location
      @location = Location.find(params[:id].to_s)
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

    def allowed_location_description_params
      params.require(:description).
        permit(:source_type, :source_name, :project_id, :public_write, :public,
               :license_id, :gen_desc, :ecology, :species, :notes, :refs)
    end
  end
end
