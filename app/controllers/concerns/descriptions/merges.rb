# frozen_string_literal: true

#  merge_descriptions::
#  perform_merge::                      Merge 1 description into another if it
#                                       can.
#  merge_description_notes::            Merge the notes fields of 2 descriptions

module Descriptions::Merges
  extend ActiveSupport::Concern

  included do
    # Form to merge a description with another. User must be both an admin for
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

    # POST method. Either merges descriptions, or tries to facilitate a merge.
    def create
      return unless check_src_exists! && check_src_permission!

      return unless check_dest_exists!

      @description = @src
      @delete_after = (params[:delete] == "1")
      merge_descriptions
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
      return true if (@dest = find_description!(target))

      flash_error(:runtime_invalid.t(type: '"target"', value: target))
      false
    end

    # Perform actual merge of two descriptions within the same parent.
    # If there is a merge conflict, e.g. with notes, it dumps the user into
    # the edit_description form and forces them to do the merge and delete the
    # old description afterward.
    def merge_descriptions
      return unless check_dest_permission!

      # Try merge.
      if perform_merge
        # Merged successfully.
        log_the_merge_flash_and_redirect
      else
        # If conflict: render edit form.
        warn_and_render_edit_description_form
      end
    end

    def check_dest_permission!
      return true if in_admin_mode? || @dest.writer?(@user)

      flash_error(:runtime_edit_description_denied.t)
      @description = @src
      render("new")
      false
    end

    # Attempt to merge one description into another, deleting the old one
    # if requested.  It will only do so if there is no conflict on any of the
    # description fields, i.e. one or the other is blank for any given field.
    def perform_merge
      src_notes  = @src.all_notes
      dest_notes = @dest.all_notes
      result = false

      # Mergeable if there are no fields which are non-blank in
      # both descriptions.
      if @src.class.all_note_fields.none? \
           { |f| src_notes[f].present? && dest_notes[f].present? }
        result = true

        # Copy over all non-blank descriptive fields.
        src_notes.each do |f, val|
          @dest.send(:"#{f}=", val) if val.present?
        end

        # Save changes to destination.
        @dest.save

        # Copy over authors and editors.
        @src.authors.each { |user| @dest.add_author(user) }
        @src.editors.each { |user| @dest.add_editor(user) }

        # Delete old description if requested.
        delete_src_description_and_update_parent if @delete_after
      end

      result
    end

    def log_the_merge_flash_and_redirect
      @dest.parent.log(:log_object_merged_by_user,
                       user: @user.login,
                       touch: true,
                       from: @src.unique_partial_format_name,
                       to: @dest.unique_partial_format_name)
      flash_notice(:runtime_description_merge_success.
           t(old: @src.format_name, new: @dest.format_name))
      redirect_to(object_path_with_query(@dest))
    end

    def warn_and_render_edit_description_form
      flash_warning(:runtime_description_merge_conflict.t)
      @description = @dest
      @licenses = License.current_names_and_ids
      merge_description_notes
      @merge = true
      @old_desc_id = @src.id
      render("#{@src.show_controller}/edit")
    end

    # Tentatively merge the fields by sticking src's notes after dest's wherever
    # there is a conflict.  Give user a chance to merge them by hand.
    def merge_description_notes
      src_notes  = @src.all_notes
      dest_notes = @dest.all_notes
      src_notes.each_key do |f|
        if dest_notes[f].blank?
          dest_notes[f] = src_notes[f]
        elsif src_notes[f].present?
          dest_notes[f] += "\n\n--------------------------------------\n\n"
          dest_notes[f] += src_notes[f].to_s
        end
      end
      @dest.all_notes = dest_notes
    end

    def delete_src_description_and_update_parent
      if !in_admin_mode? && !@src.is_admin?(@user)
        flash_warning(:runtime_description_merge_delete_denied.t)
      else
        flash_notice(:runtime_description_merge_deleted.
                       t(old: @src.unique_partial_format_name))
        @src.destroy

        # Make destination the default if source used to be the default.
        src_was_default = (@src.parent.description_id == @src.id)
        if src_was_default && @dest.fully_public?
          @dest.parent.description = @dest
          @dest.parent.save
        end
      end
    end

    include ::Descriptions
  end
end
