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
    include ::Descriptions
    include ::Names::Descriptions::SharedPrivateMethods

    before_action :store_location, except: [:index, :destroy]
    before_action :login_required

    ############################################################################
    # INDEX
    #
    def index
      build_index_with_query
    end

    def controller_model_name
      "NameDescription"
    end

    private

    def default_sort_order
      ::Query::NameDescriptions.default_order # :name
    end

    # Used by ApplicationController to dispatch #index to a private method
    def index_active_params
      [:by_author, :by_editor, :by, :q, :id].freeze
    end

    # Display list of name_descriptions that a given user is author on.
    def by_author
      user = find_obj_or_goto_index(
        model: User, obj_id: params[:by_author].to_s,
        index_path: name_descriptions_index_path
      )
      return unless user

      query = create_query(:NameDescription, by_author: user)
      [query, {}]
    end

    # Display list of name_descriptions that a given user is editor on.
    def by_editor
      user = find_obj_or_goto_index(
        model: User, obj_id: params[:by_editor].to_s,
        index_path: name_descriptions_index_path
      )
      return unless user

      query = create_query(:NameDescription, by_editor: user)
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
        redirect_to_next_object(:next, NameDescription, params[:id].to_s)
      when "prev"
        redirect_to_next_object(:prev, NameDescription, params[:id].to_s)
      end

      @name = @description.name
      return unless description_parent_exists?(@name)
      return unless user_has_permission_to_see_description?

      update_view_stats(@description)
      @canonical_url = description_canonical_url(@description)
      @projects = users_projects_which_dont_have_desc_of_this(@name)
      @versions = @description.versions
      @comments = @description.comments&.sort_by(&:created_at)&.reverse
    end

    ############################################################################
    #
    #  :section: Create and Edit Name Descriptions
    #
    ############################################################################

    def new
      find_name
      find_licenses
      @description = NameDescription.new
      @description.name = @name

      # Render a blank form.
      initialize_description_source
    end

    def create
      find_name
      find_licenses
      @description = NameDescription.new
      @description.name = @name

      # Create new description.
      @description.attributes = permitted_name_description_params
      @description.source_type = @description.source_type.to_sym
      if @description.valid?
        save_new_description_flash_and_redirect
      else
        flash_object_errors(@description)
        render_new
      end
    end

    private

    def find_name
      @name = Name.find(params[:name_id].to_s)
    end

    def find_description_parent
      @name = Name.find(@description.parent_id.to_s)
    end

    def render_new
      render("new", location: new_name_description_path(@name.id))
    end

    def render_edit
      render("edit", location: edit_name_description_path(@name.id))
    end

    # called by :create
    def save_new_description_flash_and_redirect
      initialize_description_permissions
      @description.save

      set_default_description_if_public
      update_parent_classification_cache
      @name.save if @name.changed?
      log_description_created
      flash_notice(:runtime_name_description_success.t(id: @description.id))

      redirect_to(@description.show_link_args)
    end

    # called by :create. Make this the "default" description
    # if there isn't one and this is publicly readable and writable.
    def set_default_description_if_public
      return unless !@name.description && @description.fully_public?

      @name.description = @description
    end

    # called by :create
    # Keep the parent's classification cache up to date.
    def update_parent_classification_cache
      return unless (@name.description == @description) &&
                    (@name.classification != @description.classification)

      @name.classification = @description.classification
    end

    public

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
      @description.attributes = permitted_name_description_params
      @description.source_type = @description.source_type.to_sym

      modify_description_permissions # does not redirect
      update_review_status_if_changes_substantial # does not redirect
      save_updated_description_if_changed_or_flash
    end

    private

    # called by :update
    # If substantive changes are made by a reviewer, call this act a
    # "review", even though they haven't actually changed the review
    # status.  If it's a non-reviewer, this will revert it to "unreviewed".
    def update_review_status_if_changes_substantial
      return unless @description.save_version?

      @description.update_review_status(@description.review_status)
    end

    # called by :update
    def save_updated_description_if_changed_or_flash
      # No changes made.
      if !@description.changed?
        flash_warning(:runtime_edit_name_description_no_change.t)
        render_edit

      # Try to save and flash if there were error(s).
      elsif !@description.save
        flash_object_errors(@description)
        render_edit

      # Updated successfully.
      else
        flash_notice(
          :runtime_edit_name_description_success.t(id: @description.id)
        )
        update_classification_cache_and_save_name
        log_description_updated
        resolve_merge_conflicts_and_delete_old_description # does not redirect
        redirect_to(@description.show_link_args)
      end
    end

    # Update name's classification cache.
    def update_classification_cache_and_save_name
      name = @description.name
      if (name.description == @description) &&
         (name.classification != @description.classification)
        name.classification = @description.classification
        name.save if name.changed?
      end
    end

    # TODO: should public, public_write and source_type be removed from list?
    # They should be individually checked and set, since we
    # don't want them to have arbitrary values
    def permitted_name_description_params
      params.required(:description).
        permit(:classification, :gen_desc, :diag_desc, :distribution, :habitat,
               :look_alikes, :uses, :refs, :notes, :source_name, :project_id,
               :source_type, :public, :public_write)
    end

    public

    def destroy
      return unless find_description!

      check_delete_permission_flash_and_redirect
    end
  end
end
