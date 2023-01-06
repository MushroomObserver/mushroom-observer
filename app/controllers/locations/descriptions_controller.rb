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
    include Descriptions

    before_action :login_required
    before_action :disable_link_prefetching, except: [
      :new, :create,
      :edit, :update,
      :show
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
        locations_by_author
      elsif params[:by_editor].present?
        locations_by_editor
      elsif params[:by].present?
        index_location
      else
        list_locations
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
        action: :list_location_descriptions,
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
      store_location
      pass_query_params
      @description = find_or_goto_index(LocationDescription, params[:id].to_s)
      return unless @description

      @canonical_url = "#{MO.http_domain}/locations/descriptions/" \
                       "#{@description.id}"
      # Public or user has permission.
      if in_admin_mode? || @description.is_reader?(@user)
        @location = @description.location
        update_view_stats(@description)

        # Get a list of projects the user can create drafts for.
        @projects = @user&.projects_member&.select do |project|
          @location.descriptions.none? { |d| d.belongs_to_project?(project) }
        end

      # User doesn't have permission to see this description.
      elsif @description.source_type == "project"
        flash_error(:runtime_show_draft_denied.t)
        if (project = @description.project)
          redirect_to(controller: :project, action: :show_project,
                      id: project.id)
        else
          redirect_to(action: :show_location, id: @description.location_id)
        end
      else
        flash_error(:runtime_show_description_denied.t)
        redirect_to(action: :show_location, id: @description.location_id)
      end
    end

    # Go to next location: redirects to show_location.
    def next_location_description
      redirect_to_next_object(:next, LocationDescription, params[:id].to_s)
    end

    # Go to previous location: redirects to show_location.
    def prev_location_description
      redirect_to_next_object(:prev, LocationDescription, params[:id].to_s)
    end

    def create_location_description
      store_location
      pass_query_params
      @location = Location.find(params[:id].to_s)
      @licenses = License.current_names_and_ids
      @description = LocationDescription.new
      @description.location = @location

      # Render a blank form.
      if request.method == "GET"
        initialize_description_source(@description)

      # Create new description.
      else
        @description.attributes = whitelisted_location_description_params

        if @description.valid?
          initialize_description_permissions(@description)
          @description.save

          # Log action in parent location.
          @description.location.log(:log_description_created,
                                    user: @user.login, touch: true,
                                    name: @description.unique_partial_format_name)

          flash_notice(
            :runtime_location_description_success.t(id: @description.id)
          )
          redirect_to(action: :show_location_description,
                      id: @description.id)

        else
          flash_object_errors(@description)
        end
      end
    end

    def edit_location_description
      store_location
      pass_query_params
      @description = LocationDescription.find(params[:id].to_s)
      @licenses = License.current_names_and_ids

      # check_description_edit_permission is partly broken.
      # It, LocationController, and NameController need repairs.
      # See https://www.pivotaltracker.com/story/show/174737948
      if !check_description_edit_permission(@description,
                                            params[:description])
        # already redirected

      elsif request.method == "POST"
        @description.attributes = whitelisted_location_description_params

        # Modify permissions based on changes to the two "public" checkboxes.
        modify_description_permissions(@description)

        # No changes made.
        if !@description.changed?
          flash_warning(:runtime_edit_location_description_no_change.t)
          redirect_to(action: :show_location_description,
                      id: @description.id)

        # There were error(s).
        elsif !@description.save
          flash_object_errors(@description)

        # Updated successfully.
        else
          flash_notice(
            :runtime_edit_location_description_success.t(id: @description.id)
          )

          # Log action in parent location.
          @description.location.log(:log_description_updated,
                                    user: @user.login, touch: true,
                                    name: @description.unique_partial_format_name)

          # Delete old description after resolving conflicts of merge.
          if (params[:delete_after] == "true") &&
             (old_desc = LocationDescription.safe_find(params[:old_desc_id]))
            if !in_admin_mode? && !old_desc.is_admin?(@user)
              flash_warning(:runtime_description_merge_delete_denied.t)
            else
              flash_notice(:runtime_description_merge_deleted.
                             t(old: old_desc.partial_format_name))
              @description.location.log(
                :log_object_merged_by_user,
                user: @user.login, touch: true,
                from: old_desc.unique_partial_format_name,
                to: @description.unique_partial_format_name
              )
              old_desc.destroy
            end
          end

          redirect_to(action: :show_location_description,
                      id: @description.id)
        end
      end
    end

    def destroy_location_description
      pass_query_params
      @description = LocationDescription.find(params[:id].to_s)
      if in_admin_mode? || @description.is_admin?(@user)
        flash_notice(:runtime_destroy_description_success.t)
        @description.location.log(:log_description_destroyed,
                                  user: @user.login, touch: true,
                                  name: @description.unique_partial_format_name)
        @description.destroy
        redirect_with_query(action: :show_location,
                            id: @description.location_id)
      else
        flash_error(:runtime_destroy_description_not_admin.t)
        if in_admin_mode? || @description.is_reader?(@user)
          redirect_with_query(action: :show_location_description,
                              id: @description.id)
        else
          redirect_with_query(action: :show_location,
                              id: @description.location_id)
        end
      end
    end

    def whitelisted_location_description_params
      params.require(:description).
        permit(:source_type, :source_name, :project_id, :public_write, :public,
               :license_id, :gen_desc, :ecology, :species, :notes, :refs)
    end
  end
end
