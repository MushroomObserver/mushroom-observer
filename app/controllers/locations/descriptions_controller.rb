# frozen_string_literal: true

module Locations
  class DescriptionsController < ApplicationController
    include ::Descriptions
    include ::Locations::Descriptions::SharedPrivateMethods

    # disable cop because index is defined in ApplicationController
    # rubocop:disable Rails/LexicallyScopedActionFilter
    before_action :store_location, except: [:index, :destroy]
    before_action :pass_query_params, except: [:index]
    # rubocop:enable Rails/LexicallyScopedActionFilter
    before_action :login_required
    before_action :require_successful_user, only: [
      :new, :create
    ]

    ############################################################################
    #
    #  Index

    # Used by ApplicationController to dispatch #index to a private method
    @index_subaction_param_keys = [
      :by_author,
      :by_editor,
      :by,
      :q,
      :id
    ].freeze

    @index_subaction_dispatch_table = {
      by: :index_query_results,
      q: :index_query_results,
      id: :index_query_results
    }.freeze

    private # private methods used by #index  ##################################

    def default_index_subaction
      list_all
    end

    # Displays a list of all location_descriptions.
    def list_all
      query = create_query(:LocationDescription, :all, by: default_sort_order)
      show_selected_location_descriptions(query)
    end

    def default_sort_order
      ::Query::LocationDescriptionBase.default_order
    end

    # Displays a list of selected locations, based on current Query.
    def index_query_results
      query = find_or_create_query(:LocationDescription, by: params[:by])
      show_selected_location_descriptions(query, id: params[:id].to_s,
                                                 always_index: true)
    end

    # Display list of location_descriptions that a given user is author on.
    def by_author
      user = find_obj_or_goto_index(
        model: User, obj_id: params[:by_author].to_s,
        index_path: location_descriptions_path
      )
      return unless user

      query = create_query(:LocationDescription, :by_author, user: user)
      show_selected_location_descriptions(query)
    end

    # Display list of location_descriptions that a given user is editor on.
    def by_editor
      user = find_obj_or_goto_index(
        model: User, obj_id: params[:by_editor].to_s,
        index_path: location_descriptions_path
      )
      return unless user

      query = create_query(:LocationDescription, :by_editor, user: user)
      show_selected_location_descriptions(query)
    end

    # Show selected search results as a list with 'list_locations' template.
    def show_selected_location_descriptions(query, args = {})
      store_query_in_session(query)

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

      show_index_of_objects(query, args)
    end

    ############################################################################

    public

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
      pass_query_params
      return unless find_description!

      check_delete_permission_flash_and_redirect
    end

    ############################################################################

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

    def permitted_location_description_params
      params.require(:description).
        permit(:source_type, :source_name, :project_id, :public_write, :public,
               :license_id, :gen_desc, :ecology, :species, :notes, :refs)
    end
  end
end
