# frozen_string_literal: true

#  == DESCRIPTIONS
#   index_name_description::     List of results of index/search.
#   list_name_descriptions::     Alphabetical list of all name_descriptions,
#                                used or otherwise.
#   name_descriptions_by_author::Alphabetical list of name_descriptions authored
#                                by given user.
#   name_descriptions_by_editor::Alphabetical list of name_descriptions edited
#                                by given user.
#  show_name_description::       Show info about name_description.
#   prev_name_description::      Show previous name_description in index.
#   next_name_description::      Show next name_description in index.
#  create_name_description::     Create new name_description.
#  edit_name_description::       Edit name_description.
#  destroy_name_description::    Destroy name_description.

module Names
  class DescriptionsController < ApplicationController
    include Descriptions
    include ::Names::Descriptions::SharedPrivateMethods

    before_action :login_required
    before_action :disable_link_prefetching, except: [
      :show, :new, :create, :edit, :update
    ]

    ############################################################################
    #
    #  :section: Description Indexes and Searches
    #
    ############################################################################

    def index
      if params[:by_author].present?
        name_descriptions_by_user
      elsif params[:by_editor].present?
        name_descriptions_by_editor
      elsif params[:by].present?
        index_name_description
      else
        list_name_descriptions
      end
    end

    private

    # Display list of names in last index/search query.
    def index_name_description
      query = find_or_create_query(:NameDescription, by: params[:by])
      show_selected_name_descriptions(query, id: params[:id].to_s,
                                             always_index: true)
    end

    # Display list of all (correctly-spelled) name_descriptions in the database.
    def list_name_descriptions
      query = create_query(:NameDescription, :all, by: :name)
      show_selected_name_descriptions(query)
    end

    # Display list of name_descriptions that a given user is author on.
    def name_descriptions_by_author
      user = if params[:by_author]
               find_or_goto_index(User, params[:by_author].to_s)
             else
               @user
             end
      return unless user

      query = create_query(:NameDescription, :by_author, user: user)
      show_selected_name_descriptions(query)
    end

    # Display list of name_descriptions that a given user is editor on.
    def name_descriptions_by_editor
      user = if params[:by_editor]
               find_or_goto_index(User, params[:by_editor].to_s)
             else
               @user
             end
      return unless user

      query = create_query(:NameDescription, :by_editor, user: user)
      show_selected_name_descriptions(query)
    end

    # Show selected search results as a list with ???
    #              'names/descriptions/index' template ???
    def show_selected_name_descriptions(query, args = {})
      store_query_in_session(query)
      @links ||= []
      args = {
        controller: "names/descriptions",
        action: "index",
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

    public

    # --------------------------------------------------------------------------

    def show
      store_location
      pass_query_params
      return unless find_description!

      case params[:flow]
      when "next"
        redirect_to_next_object(:next, NameDescription, params[:id].to_s)
      when "prev"
        redirect_to_next_object(:prev, NameDescription, params[:id].to_s)
      end

      @name = @description.name
      return unless description_name_exists?(@location)
      return unless user_has_permission_to_see_description?

      update_view_stats(@description)
      @canonical_url = description_canonical_url(@description)
      @projects = users_projects_which_dont_have_desc_of_this_name
    end

    ############################################################################
    #
    #  :section: Create and Edit Name Descriptions
    #
    ############################################################################

    def new
      store_location
      pass_query_params
      find_name
      find_licenses
      @description = NameDescription.new
      @description.name = @name

      # Render a blank form.
      initialize_description_source(@description)
    end

    def create
      store_location
      pass_query_params
      find_name
      find_licenses
      @description = NameDescription.new
      @description.name = @name

      # Create new description.
      @description.attributes = allowed_name_description_params
      @description.source_type = @description.source_type.to_sym

      check_create_validity_and_save_or_flash_and_redirect
    end

    def edit
      store_location
      pass_query_params
      return unless find_description!

      find_licenses

      # check_description_edit_permission is partly broken.
      # It, LocationController, and NameController need repairs.
      # See https://www.pivotaltracker.com/story/show/174737948
      check_description_edit_permission(@description,
                                        params[:description])
    end

    def update
      store_location
      pass_query_params
      return unless find_description!

      find_licenses

      check_description_edit_permission(@description,
                                        params[:description])
      @description.attributes = allowed_name_description_params
      @description.source_type = @description.source_type.to_sym

      # Modify permissions based on changes to the two "public" checkboxes.
      modify_description_permissions(@description)

      # If substantive changes are made by a reviewer, call this act a
      # "review", even though they haven't actually changed the review
      # status.  If it's a non-reviewer, this will revert it to "unreviewed".
      if @description.save_version?
        @description.update_review_status(@description.review_status)
      end

      save_if_changes_made_or_flash
    end

    def destroy
      pass_query_params
      return unless find_description!

      check_delete_permission_flash_and_redirect
    end

    private

    def find_name
      @name = Name.find(params[:id].to_s)
    end

    def find_licenses
      @licenses = License.current_names_and_ids
    end

    def check_create_validity_and_save_or_flash_and_redirect
      if @description.valid?
        initialize_description_permissions(@description)
        @description.save

        set_default_description_if_public
        update_classification_cache(@name)
        log_description_created

        flash_notice(:runtime_name_description_success.t(id: @description.id))
        redirect_to(name_description_path(@description.id))
      else
        flash_object_errors(@description)
      end
    end

    # Make this the "default" description if there isn't one and this is
    # publicly readable and writable.
    def set_default_description_if_public
      return unless !@name.description && @description.fully_public

      @name.description = @description
    end

    # Log action in parent name.
    def log_description_created
      @description.name.log(:log_description_created,
                            user: @user.login,
                            touch: true,
                            name: @description.unique_partial_format_name)
    end

    def save_if_changes_made_or_flash
      # No changes made.
      if !@description.changed?
        flash_warning(:runtime_edit_name_description_no_change.t)
        redirect_to(name_description_path(@description.id))

      # There were error(s).
      elsif !@description.save
        flash_object_errors(@description)

      # Updated successfully.
      else
        save_flash_success_and_redirect
      end
    end

    def save_flash_success_and_redirect
      flash_notice(
        :runtime_edit_name_description_success.t(id: @description.id)
      )
      name = @description.name
      update_classification_cache(name)
      log_description_updated(name)
      resolve_merge_conflicts_and_delete_old_description(name)
      redirect_to(name_description_path(@description.id))
    end

    # Update name's classification cache.
    def update_classification_cache(name)
      if (name.description == @description) &&
         (name.classification != @description.classification)
        name.classification = @description.classification
        name.save if name.changed?
      end
    end

    # Log action to parent name.
    def log_description_updated(name)
      name.log(:log_description_updated,
               touch: true,
               user: @user.login,
               name: @description.unique_partial_format_name)
    end

    # Delete old description after resolving conflicts of merge.
    def resolve_merge_conflicts_and_delete_old_description(name)
      if (params[:delete_after] == "true") &&
         (old_desc = NameDescription.safe_find(params[:old_desc_id]))
        if !in_admin_mode? && !old_desc.is_admin?(@user)
          flash_warning(:runtime_description_merge_delete_denied.t)
        else
          flash_notice(:runtime_description_merge_deleted.
                          t(old: old_desc.partial_format_name))
          log_description_merged(name)
          old_desc.destroy
        end
      end
    end

    # Log merge to parent name.
    def log_description_merged(name)
      name.log(:log_object_merged_by_user,
               touch: true,
               user: @user.login,
               from: old_desc.unique_partial_format_name,
               to: @description.unique_partial_format_name)
    end

    def check_delete_permission_flash_and_redirect
      if in_admin_mode? || @description.is_admin?(@user)
        flash_notice(:runtime_destroy_description_success.t)
        log_description_destroyed
        @description.destroy
        redirect_to(name_path(@description.name_id, q: get_query_param))
      else
        flash_error(:runtime_destroy_description_not_admin.t)
        redirect_if_description_not_destroyed
      end
    end

    def log_description_destroyed
      @description.name.log(:log_description_destroyed,
                            user: @user.login,
                            touch: true,
                            name: @description.unique_partial_format_name)
    end

    def redirect_if_description_not_destroyed
      if in_admin_mode? || @description.is_reader?(@user)
        redirect_to(
          name_description_path(@description.id, q: get_query_param)
        )
      else
        redirect_to(name_path(@description.name_id, q: get_query_param))
      end
    end

    # TODO: should public, public_write and source_type be removed from list?
    # They should be individually checked and set, since we
    # don't want them to have arbitrary values
    def allowed_name_description_params
      params.required(:description).
        permit(:classification, :gen_desc, :diag_desc, :distribution, :habitat,
               :look_alikes, :uses, :refs, :notes, :source_name, :project_id,
               :source_type, :public, :public_write)
    end
  end
end
