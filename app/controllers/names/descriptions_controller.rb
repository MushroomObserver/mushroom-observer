# frozen_string_literal: true

#
#  = Name Descriptions Controller
#
#  == Actions
#   L = login required
#   R = root required
#   V = has view
#   P = prefetching allowed
#
#  index_name_description::      List of results of index/search.
#  index::                       Alphabetical list of all name_descriptions,
#                                used or otherwise.
#  name_descriptions_by_author:: Alphabetical list of name_descriptions authored
#                                by given user.
#  name_descriptions_by_editor:: Alphabetical list of name_descriptions edited
#                                by given user.
#  show::                        Show info about name_description.
#  show_prev::                   Show previous name_description in index.
#  show_next::                   Show next name_description in index.
#  show_past_name_description::  Show past versions of name_description info.
#  new::                         Create new name_description.
#  edit::                        Edit name_description.
#  make_description_default::    Make a description the default one.
#  merge_descriptions::          Merge a description with another.
#  publish_description::         Publish a draft description.
#  adjust_permissions::          Adjust permissions on a description.
#
#  for more on this pattern:
#  http://jeromedalbert.com/how-dhh-organizes-his-rails-controllers/

class Names::DescriptionsController < ApplicationController

  include DescriptionControllerHelpers

  # rubocop:disable Rails/LexicallyScopedActionFilter
  # No idea how to fix this offense.  If I add another
  #    before_action :login_required, except: :show_name_description
  # in name_controller/show_name_description.rb, it ignores it.
  before_action :login_required, except: [
    :index,
    :index_name_description,
    :list_name_descriptions, # aliased
    :name_descriptions_by_author,
    :name_descriptions_by_editor,
    :next_name_description, # aliased
    :prev_name_description, # aliased
    :show,
    :show_next,
    :show_prev,
    :show_name_description, # aliased
    :show_past_name_description
  ]

  before_action :disable_link_prefetching, except: [
    :create,
    :create_name_description, # aliased
    :edit,
    :edit_name_description, # aliased
    :show,
    :show_name_description, # aliased
    :show_past_name_description
  ]
  # rubocop:enable Rails/LexicallyScopedActionFilter

  ##############################################################################
  #
  #  :section: Description Indexes and Searches
  #
  ##############################################################################

  # Display list of names in last index/search query.
  def index_name_description
    query = find_or_create_query(
      :NameDescription,
      by: params[:by]
    )
    show_selected_name_descriptions(query, id: params[:id].to_s,
                                           always_index: true)
  end

  # Display list of all (correctly-spelled) name_descriptions in the database.
  def index
    query = create_query(
      :NameDescription,
      :all,
      by: :name
    )
    show_selected_name_descriptions(query)
  end

  alias_method :list_name_descriptions, :index

  # Display list of name_descriptions that a given user is author on.
  def name_descriptions_by_author
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(
      :NameDescription,
      :by_author,
      user: user
    )
    show_selected_name_descriptions(query)
  end

  # Display list of name_descriptions that a given user is editor on.
  def name_descriptions_by_editor
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(
      :NameDescription,
      :by_editor,
      user: user
    )
    show_selected_name_descriptions(query)
  end

  # Show selected search results as a list with 'list_names' template.
  def show_selected_name_descriptions(query, args = {})
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

    # Add "show names" link if this query can be coerced into an
    # observation query.
    @links << coerced_query_link(query, Name)

    show_index_of_objects(query, args)
  end

  ##############################################################################
  #
  #  :section: Show Name Description
  #
  ##############################################################################

  def show
    store_location
    pass_query_params
    @description = find_or_goto_index(NameDescription, params[:id].to_s)
    return unless @description

    @name = @description.name
    return unless description_name_exists?
    return unless user_has_permission_to_see_description?

    update_view_stats(@description)
    @canonical_url = description_canonical_url
    @projects = users_projects_which_dont_have_desc_of_this_name
  end

  alias_method :show_name_description, :show

  # ----------------------------------------------------------------------------

  protected

  def description_name_exists?
    return true if @name

    flash_error(:runtime_name_for_description_not_found.t)
    redirect_to names_path
    false
  end

  def user_has_permission_to_see_description?
    return true if in_admin_mode? || @description.is_reader?(@user)

    if @description.source_type == :project
      flash_error(:runtime_show_draft_denied.t)
    else
      flash_error(:runtime_show_description_denied.t)
    end
    redirect_to_name_or_project
  end

  def redirect_to_name_or_project
    if @description.project
      # redirect_to(
      #   controller: :projects,
      #   action: :show,
      #   id: @description.project_id
      # )
      redirect_to project_path(@description.project_id)
    else
      # redirect_to(
      #   controller: :names,
      #   action: :show,
      #   id: @description.name_id
      # )
      redirect_to name_path(@description.name_id)
    end
  end

  # this was /name/show_name_description/#{@description.id} - NIMMO
  def description_canonical_url
    "#{MO.http_domain}/names/#{@name.id}/descriptions/#{@description.id}"
  end

  def users_projects_which_dont_have_desc_of_this_name
    return [] unless @user

    @user.projects_member.select do |project|
      @name.descriptions.none? { |d| d.belongs_to_project?(project) }
    end
  end

  # Show past version of NameDescription.  Accessible only from
  # show_name_description page.
  def show_past_name_description
    pass_query_params
    store_location
    @description = find_or_goto_index(NameDescription, params[:id].to_s)
    return unless @description

    @name = @description.name
    if params[:merge_source_id].blank?
      @description.revert_to(params[:version].to_i)
    else
      @merge_source_id = params[:merge_source_id]
      version = NameDescription::Version.find(@merge_source_id)
      @old_parent_id = version.name_description_id
      subversion = params[:version]
      if subversion.present? &&
         (version.version != subversion.to_i)
        version = NameDescription::Version.
                  find_by_version_and_name_description_id(params[:version],
                                                          @old_parent_id)
      end
      @description.clone_versioned_model(version, @description)
    end
  end

  # Go to next name: redirects to show_name.
  def show_next
    redirect_to_next_object(:next, NameDescription, params[:id].to_s)
  end

  alias_method :next_name_description, :show_next

  # Go to previous name_description: redirects to show_name_description.
  def show_prev
    redirect_to_next_object(:prev, NameDescription, params[:id].to_s)
  end

  alias_method :prev_name_description, :show_prev

  # Callback to let reviewers change the review status of a Name from the
  # show_name page.
  def set_review_status
    pass_query_params
    id = params[:id].to_s
    desc = NameDescription.find(id)
    desc.update_review_status(params[:value]) if reviewer?
    # redirect_with_query(
    #   controller: :names,
    #   action: :show,
    #   id: desc.name_id
    # )
    redirect_to name_path(desc.name_id, :q => get_query_param)
  end

  ##############################################################################
  #
  #  :section: Create and Edit Name Descriptions
  #
  ##############################################################################

  def new
    store_location
    pass_query_params
    @name = Name.find(params[:id].to_s)
    @licenses = License.current_names_and_ids
    @description = NameDescription.new
    @description.name = @name

    # Render a blank form.
    initialize_description_source(@description)
  end

  alias_method :create_name_description, :new

  def create
    @description.attributes = whitelisted_name_description_params
    @description.source_type = @description.source_type.to_sym

    if @description.valid?
      initialize_description_permissions(@description)
      @description.save

      # Make this the "default" description if there isn't one and this is
      # publicly readable and writable.
      if !@name.description && @description.fully_public
        @name.description = @description
      end

      # Keep the parent's classification cache up to date.
      if (@name.description == @description) &&
         (@name.classification != @description.classification)
        @name.classification = @description.classification
      end

      # Log action in parent name.
      @description.name.log(:log_description_created,
                            user: @user.login,
                            touch: true,
                            name: @description.unique_partial_format_name)

      # Save any changes to parent name.
      @name.save if @name.changed?

      flash_notice(:runtime_name_description_success.t(id: @description.id))
      # redirect_to(
      #   action: :show,
      #   id: @description.id
      # )
      redirect_to name_description_path(@description.name_id, @description.id)
    else
      flash_object_errors @description
    end
  end

  # :prefetch: :norobots:
  def edit
    store_location
    pass_query_params
    @description = NameDescription.find(params[:id].to_s)
    @licenses = License.current_names_and_ids

    if !check_description_edit_permission(@description, params[:description])
    # already redirected
  end

  alias_method :edit_name_description, :edit

  def update
    @description.attributes = whitelisted_name_description_params
    @description.source_type = @description.source_type.to_sym

    # Modify permissions based on changes to the two "public" checkboxes.
    modify_description_permissions(@description)

    # If substantive changes are made by a reviewer, call this act a
    # "review", even though they haven't actually changed the review
    # status.  If it's a non-reviewer, this will revert it to "unreviewed".
    if @description.save_version?
      @description.update_review_status(@description.review_status)
    end

    # No changes made.
    if !@description.changed?
      flash_warning(:runtime_edit_name_description_no_change.t)
      # redirect_to(
      #   action: :show,
      #   id: @description.id
      # )
      redirect_to name_description_path(@description.name_id, @description.id)

    # There were error(s).
    elsif !@description.save
      flash_object_errors(@description)

    # Updated successfully.
    else
      flash_notice(
        :runtime_edit_name_description_success.t(id: @description.id)
      )

      # Update name's classification cache.
      name = @description.name
      if (name.description == @description) &&
         (name.classification != @description.classification)
        name.classification = @description.classification
        name.save
      end

      # Log action to parent name.
      name.log(:log_description_updated,
               touch: true,
               user: @user.login,
               name: @description.unique_partial_format_name)

      # Delete old description after resolving conflicts of merge.
      if (params[:delete_after] == "true") &&
         (old_desc = NameDescription.safe_find(params[:old_desc_id]))
        v = @description.versions.latest
        v.merge_source_id = old_desc.versions.latest.id
        v.save
        if !in_admin_mode? && !old_desc.is_admin?(@user)
          flash_warning(:runtime_description_merge_delete_denied.t)
        else
          flash_notice(:runtime_description_merge_deleted.
                         t(old: old_desc.partial_format_name))
          name.log(:log_object_merged_by_user,
                   user: @user.login, touch: true,
                   from: old_desc.unique_partial_format_name,
                   to: @description.unique_partial_format_name)
          old_desc.destroy
        end
      end

      # redirect_to(
      #   action: :show,
      #   id: @description.id
      # )
      redirect_to name_description_path(@description.name_id, @description.id)
    end
  end

  def destroy
    pass_query_params
    @description = NameDescription.find(params[:id].to_s)
    if in_admin_mode? || @description.is_admin?(@user)
      flash_notice(:runtime_destroy_description_success.t)
      @description.name.log(:log_description_destroyed,
                            user: @user.login,
                            touch: true,
                            name: @description.unique_partial_format_name)
      @description.destroy
      # redirect_with_query(
      #   controller: :names,
      #   action: :show,
      #   id: @description.name_id
      # )
      redirect_to name_path(@description.name_id, :q => get_query_param)
    else
      flash_error(:runtime_destroy_description_not_admin.t)
      if in_admin_mode? || @description.is_reader?(@user)
        # redirect_with_query(
        #   action: :show,
        #   id: @description.id
        # )
        redirect_to name_description_path(@description.name_id, @description.id)
      else
        # redirect_with_query(
        #   controller: :names,
        #   action: :show,
        #   id: @description.name_id
        # )
        redirect_to name_path(@description.name_id, :q => get_query_param)
      end
    end
  end

  alias_method :destroy_name_description, :destroy

  private

  # TODO: should public, public_write and source_type be removed from this list?
  # They should be individually checked and set, since we
  # don't want them to have arbitrary values
  def whitelisted_name_description_params
    params.required(:description).
      permit(:classification, :gen_desc, :diag_desc, :distribution, :habitat,
             :look_alikes, :uses, :refs, :notes, :source_name, :project_id,
             :source_type, :public, :public_write)
  end

end
