# frozen_string_literal: true

#  new::
#  create::
#  move_description::                   Move current description to another name

module Descriptions::Moves
  extend ActiveSupport::Concern

  included do
    # Form to move a description to another name. User must be both an admin for
    # the old description (which will be destroyed) and a writer for the new one
    # (so they can modify it).
    def new
      return unless (@src = find_description!(params[:id].to_s))

      @description = @src

      # render the form, if have permission
      return if in_admin_mode? || @src.is_reader?(@user)

      # Doesn't have permission to see source.
      flash_error(:runtime_description_private.t)
      redirect_to(object_path_with_query(@src.parent))
    end

    # POST method. Moves the description to a new parent object.
    def create
      return unless check_src_exists! && check_src_permission!

      @description = @src
      return unless check_dest_exists!

      @delete_after = (params[:delete] == "1")
      move_description
    end

    private

    def check_src_exists!
      return true if (@src = find_description!(params[:id].to_s))

      false
    end

    def check_src_permission!
      return true if in_admin_mode? || @src.is_reader?(@user)

      flash_error(:runtime_description_private.t)
      redirect_to(object_path_with_query(@src.parent))
      false
    end

    def check_dest_exists!
      target = params[:target].to_s
      return true if (@dest = find_or_goto_index(@src.parent.class, target))

      flash_error(:runtime_invalid.t(type: '"target"', value: target))
      false
    end

    # Perform actual move of a description from one name to another.
    def move_description
      if @delete_after
        move_description_to_another_name
      else
        clone_description_to_another_name
      end
    end

    # Just transfer the description over.
    def move_description_to_another_name
      src_was_default = (@src.parent.description_id == @src.id)
      make_dest_default = @dest.description_id.nil? && src_was_default

      remove_parent_default_desc_and_log_it if src_was_default
      set_src_parent_to_dest_and_log_it

      if make_dest_default && @src.fully_public?
        make_src_the_new_default_description_for_dest_and_log_it
      end

      flash_notice(:runtime_description_move_success.t(old: @src.format_name,
                                                       new: @dest.format_name))
      redirect_to(object_path_with_query(@src))
    end

    def remove_parent_default_desc_and_log_it
      @src.parent.update(description_id: nil)
      @src.parent.log(:log_changed_default_description,
                      user: @user.login,
                      name: :none,
                      touch: true)
    end

    def set_src_parent_to_dest_and_log_it
      @src.update(parent_id: @dest.id)
      @src.parent.log(:log_object_moved_by_user,
                      user: @user.login,
                      from: @src.unique_partial_format_name,
                      to: @dest.unique_format_name,
                      touch: true)
    end

    def make_src_the_new_default_description_for_dest_and_log_it
      @dest.update(description_id: @src.id)
      @dest.log(:log_changed_default_description,
                user: @user.login,
                name: @src.unique_partial_format_name,
                touch: true)
    end

    # Create a clone in the destination name/location.
    def clone_description_to_another_name
      desc = clone_src_description

      # I think a reviewer should be required to pass off on this before it
      # gets shared with reputable sources. Synonymy is never a clean science.
      # if dest.is_a?(Name)
      #   desc.review_status = src.review_status
      #   desc.last_review   = src.last_review
      #   desc.reviewer_id   = src.reviewer_id
      #   desc.ok_for_export = src.ok_for_export
      # end

      # This can really gum up the works and it's really hard to figure out
      # what the problem is when it occurs, since error message is cryptic.
      if @dest.is_a?(Name) && desc.classification.present?
        begin
          Name.validate_classification(@dest.rank, desc.classification)
        rescue StandardError => e
          flash_error(:runtime_description_move_invalid_classification.t)
          flash_error(e.to_s)
          desc.classification = ""
        end
      end

      # Okay, *now* we can try to save the new description...
      if desc.save
        @dest.log(:log_description_created,
                  user: @user.login,
                  name: desc.unique_partial_format_name,
                  touch: true)
        flash_notice(:runtime_description_copy_success.
                     t(old: @src.format_name, new: desc.format_name))
        redirect_to(object_path_with_query(desc))
      else
        flash_object_errors(desc)
      end
    end

    def clone_src_description
      @src.class.new(
        parent: @dest,
        source_type: @src.source_type,
        source_name: @src.source_name,
        project_id: @src.project_id,
        locale: @src.locale,
        public: @src.public,
        license: @src.license,
        all_notes: @src.all_notes
      )
    end

    include ::Descriptions
  end
end
