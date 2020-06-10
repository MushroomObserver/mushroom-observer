# frozen_string_literal: true

#  for more on this pattern:
#  http://jeromedalbert.com/how-dhh-organizes-his-rails-controllers/

# Location controller.
class Locations::DescriptionsController < ApplicationController

  include DescriptionControllerHelpers

  before_action :login_required, except: [
    :index,
    :index_location_description,
    :list_location_descriptions, # aliased
    :location_descriptions_by_author,
    :location_descriptions_by_editor,
    :next_location_description, # aliased
    :prev_location_description, # aliased
    :show,
    :show_location_description, # aliased
    :show_next,
    :show_prev,
    :show_past_location_description
  ]

  before_action :disable_link_prefetching, except: [
    :create_location_description, # aliased
    :edit,
    :edit_location_description, # aliased
    :new,
    :show,
    :show_location_description, # aliased
    :show_past_location_description
  ]

  before_action :require_successful_user, only: [
    :create,
    :create_location_description, # aliased
    :new
  ]

  ##############################################################################
  #
  #  :section: Description Searches and Indexes
  #
  ##############################################################################

  # Displays a list of selected locations, based on current Query.
  def index_location_description
    query = find_or_create_query(:LocationDescription, by: params[:by])
    show_selected_location_descriptions(query, id: params[:id].to_s,
                                               always_index: true)
  end

  # Displays a list of all location_descriptions.
  def index
    query = create_query(:LocationDescription, :all, by: :name)
    show_selected_location_descriptions(query)
  end

  alias_method :list_location_descriptions, :index

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

  ##############################################################################
  #
  #  :section: Show Location Description
  #
  ##############################################################################

  # Show just a LocationDescription.
  def show
    store_location
    pass_query_params
    @description = find_or_goto_index(Location::Description, params[:id].to_s)
    return unless @description

    # TODO: NIMMO - check this new url
    @canonical_url = "#{MO.http_domain}/locations/#{@description.location_id}/"\
                     "descriptions/#{@description.id}"
    # Public or user has permission.
    if in_admin_mode? || @description.is_reader?(@user)
      @location = @description.location
      update_view_stats(@description)

      # Get a list of projects the user can create drafts for.
      @projects = @user&.projects_member&.select do |project|
        @location.descriptions.none? { |d| d.belongs_to_project?(project) }
      end

    # User doesn't have permission to see this description.
    elsif @description.source_type == :project
      flash_error(:runtime_show_draft_denied.t)
      if (@project = @description.project)
        # redirect_to(
        #   controller: :projects,
        #   action: :show,
        #   id: @project.id
        # )
        redirect_to project_path(@project.id)
      else
        # redirect_to(
        #   controller: :locations,
        #   action: :show,
        #   id: @description.location_id
        # )
        redirect_to_location
      end
    else
      flash_error(:runtime_show_description_denied.t)
      # redirect_to(
      #   action: :show,
      #   id: @description.location_id
      # )
      redirect_to_location
    end
  end

  alias_method :show_location_description, :show

  # Show past version of LocationDescription.  Accessible only from
  # show_location_description page.
  def show_past_location_description
    store_location
    pass_query_params
    @description = find_or_goto_index(LocationDescription, params[:id].to_s)
    return unless @description

    @location = @description.location
    if params[:merge_source_id].blank?
      @description.revert_to(params[:version].to_i)
    else
      @merge_source_id = params[:merge_source_id]
      version = LocationDescription::Version.find(@merge_source_id)
      @old_parent_id = version.location_description_id
      subversion = params[:version]
      if subversion.present? &&
         (version.version != subversion.to_i)
        version = LocationDescription::Version.
                  find_by_version_and_location_description_id(
                    params[:version], @old_parent_id
                  )
      end
      @description.clone_versioned_model(version, @description)
    end
  end

  # Go to next location: redirects to show_location.
  def show_next
    redirect_to_next_object(:next, LocationDescription, params[:id].to_s)
  end

  alias_method :next_location_description, :show_next

  # Go to previous location: redirects to show_location.
  def show_prev
    redirect_to_next_object(:prev, LocationDescription, params[:id].to_s)
  end

  alias_method :prev_location_description, :show_prev

  ##############################################################################
  #
  #  :section: Create/Edit Location Description
  #
  ##############################################################################

  def new
    store_location
    pass_query_params
    @location = Location.find(params[:id].to_s)
    @licenses = License.current_names_and_ids
    @description = LocationDescription.new
    @description.location = @location

    # Render a blank form.
    initialize_description_source(@description)
  end

  alias_method :create_location_description, :new

  def create
    store_location
    pass_query_params
    @description = LocationDescription.new
    @description.attributes = whitelisted_location_description_params
    @description.location = @location = Location.find(params[:id].to_s)

    if @description.valid?
      initialize_description_permissions(@description)
      @description.save

      # Log action in parent location.
      @description.location.log(
        :log_description_created,
        user: @user.login,
        touch: true,
        name: @description.unique_partial_format_name
      )

      flash_notice(
        :runtime_location_description_success.t(id: @description.id)
      )
      # redirect_to(
      #   action: :show,
      #   id: @description.id
      # )
      redirect_to_location_description
    else
      flash_object_errors @description
    end
  end

  def edit
    store_location
    pass_query_params
    @description = LocationDescription.find(params[:id].to_s)
    @licenses = License.current_names_and_ids

    if !check_description_edit_permission(@description, params[:description])
      # already redirected
    end
  end

  alias_method :edit_location_description, :edit

  def update
    store_location
    pass_query_params
    @description = LocationDescription.find(params[:id].to_s)
    @location = @description.location
    @licenses = License.current_names_and_ids
    @description.attributes = whitelisted_location_description_params

    # Modify permissions based on changes to the two "public" checkboxes.
    modify_description_permissions(@description)

    # No changes made.
    if !@description.changed?
      flash_warning(:runtime_edit_location_description_no_change.t)
      # redirect_to(
      #   action: :show,
      #   id: @description.id
      # )
      redirect_to_location_description

    # There were error(s).
    elsif !@description.save
      flash_object_errors(@description)

    # Updated successfully.
    else
      flash_notice(
        :runtime_edit_location_description_success.t(id: @description.id)
      )

      # Log action in parent location.
      @description.location.log(
        :log_description_updated,
        user: @user.login,
        touch: true,
        name: @description.unique_partial_format_name
      )

      # Delete old description after resolving conflicts of merge.
      if (params[:delete_after] == "true") &&
         (old_desc = LocationDescription.safe_find(params[:old_desc_id]))
        v = @description.versions.latest
        v.merge_source_id = old_desc.versions.latest.id
        v.save
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

      # redirect_to(
      #   action: :show,
      #   id: @description.id
      # )
      redirect_to_location_description
    end

  end

  private

  def destroy
    pass_query_params
    @description = LocationDescription.find(params[:id].to_s)
    @location = @description.location
    if in_admin_mode? || @description.is_admin?(@user)
      flash_notice(:runtime_destroy_description_success.t)
      @description.location.log(
        :log_description_destroyed,
        user: @user.login,
        touch: true,
        name: @description.unique_partial_format_name
      )
      @description.destroy
      # redirect_with_query(
      #   controller: :locations,
      #   action: :show,
      #   id: @description.location_id
      # )
      redirect_to_location_with_query
    else
      flash_error(:runtime_destroy_description_not_admin.t)
      if in_admin_mode? || @description.is_reader?(@user)
        # redirect_with_query(
        #   action: :show,
        #   id: @description.id
        # )
        redirect_to_location_description_with_query
      else
        # redirect_with_query(
        #   controller: :locations,
        #   action: :show,
        #   id: @description.location_id
        # )
        redirect_to_location_with_query
      end
    end
  end

  alias_method :destroy_location_description, :destroy

  public

  ##############################################################################

  private

  def whitelisted_location_description_params
    params.require(:description).
      permit(:source_type, :source_name, :project_id, :public_write, :public,
             :license_id, :gen_desc, :ecology, :species, :notes, :refs)
  end

  def redirect_to_location
    redirect_to location_path(@description.location_id)
  end

  def redirect_to_location_with_query
    redirect_to location_path(@description.location_id, q: get_query_param)
  end

  def redirect_to_location_description
    redirect_to locations_description_path(@description.id)
  end

  def redirect_to_location_description_with_query
    redirect_to locations_description_path(@description.location_id,
      @description.id, q: get_query_param)
  end

end
