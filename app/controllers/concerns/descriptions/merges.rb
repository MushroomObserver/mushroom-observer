# frozen_string_literal: true

#  merge_descriptions::
#  perform_merge::                      Merge 1 description into another if it
#                                       can.
#  merge_description_notes::            Merge the notes fields of 2 descriptions

module Descriptions::Merges
  extend ActiveSupport::Concern

  included do
    # Merge a description with another.  User must be both an admin for the
    # old description (which will be destroyed) and a writer for the new one
    # (so they can modify it).  If there is a conflict, it dumps the user into
    # the edit_description form and forces them to do the merge and delete the
    # old description afterword.
    def merge_descriptions
      pass_query_params
      return unless (src = find_description(params[:id].to_s))

      @description = src

      # Doesn't have permission to see source.
      if !in_admin_mode? && !src.is_reader?(@user)
        flash_error(:runtime_description_private.t)
        redirect_with_query(action: src.parent.show_action, id: src.parent_id)

      # POST method
      elsif request.method == "POST"
        delete_after = (params[:delete] == "1")
        target = params[:target].to_s
        if target =~ /^parent_(\d+)$/
          target_id = Regexp.last_match(1)
          if (dest = find_or_goto_index(src.parent.class, target_id))
            do_move_description(src, dest, delete_after)
          end
        elsif target =~ /^desc_(\d+)$/
          target_id = Regexp.last_match(1)
          if (dest = find_description(target_id))
            do_merge_description(src, dest, delete_after)
          end
        else
          flash_error(:runtime_invalid.t(type: '"target"',
                                         value: target))
        end
      end
    end

    # Perform actual merge of two descriptions within the same parent.
    def do_merge_description(src, dest, delete_after)
      src_name = src.unique_partial_format_name
      src_title = src.format_name

      # Doesn't have permission to edit destination.
      if !in_admin_mode? && !dest.writer?(@user)
        flash_error(:runtime_edit_description_denied.t)
        @description = src

      # Conflict: render edit form.
      elsif !perform_merge(src, dest, delete_after)
        flash_warning(:runtime_description_merge_conflict.t)
        @description = dest
        @licenses = License.current_names_and_ids
        merge_description_notes(src, dest)
        @merge = true
        @old_desc_id = src.id
        @delete_after = delete_after
        render(action: "edit_#{src.parent.type_tag}_description")

      # Merged successfully.
      else
        desc.parent.log(:log_object_merged_by_user,
                        user: @user.login,
                        touch: true, from: src_name,
                        to: dest.unique_partial_format_name)
        flash_notice(:runtime_description_merge_success.
                     t(old: src_title, new: dest.format_name))
        redirect_with_query(action: dest.show_action, id: dest.id)
      end
    end

    # Perform actual move of a description from one name to another.
    def do_move_description(src, dest, delete_after)
      src_name = src.unique_partial_format_name
      src_title = src.format_name

      # Just transfer the description over.
      if delete_after
        make_dest_default = dest.description_id.nil? && src_was_default
        if src.parent.description_id == src.id
          src.parent.description_id = nil
          src.parent.save
          src.parent.log(:log_changed_default_description,
                         user: @user.login,
                         name: :none,
                         touch: true)
        end
        src.parent = dest
        src.save
        src.parent.log(:log_object_moved_by_user,
                       user: @user.login,
                       from: src_name,
                       to: dest.unique_format_name,
                       touch: true)
        if make_dest_default && src.fully_public
          dest.description_id = src
          dest.save
          dest.log(:log_changed_default_description,
                   user: @user.login,
                   name: src.unique_partial_format_name,
                   touch: true)
        end
        flash_notice(:runtime_description_move_success.
                     t(old: src_title, new: dest.format_name))
        redirect_with_query(action: src.show_action, id: src.id)

      # Create a clone in the destination name/location.
      else
        desc = src.class.new(
          parent: dest,
          source_type: src.source_type,
          source_name: src.source_name,
          project_id: src.project_id,
          locale: src.locale,
          public: src.public,
          license: src.license,
          all_notes: src.all_notes
        )

        # I think a reviewer should be required to pass off on this before it
        # gets shared with reputable sources.  Synonymy is never a clean science.
        # if dest.is_a?(Name)
        #   desc.review_status = src.review_status
        #   desc.last_review   = src.last_review
        #   desc.reviewer_id   = src.reviewer_id
        #   desc.ok_for_export = src.ok_for_export
        # end

        # This can really gum up the works and it's really hard to figure out
        # what the problem is when it occurs, since the error message is cryptic.
        if dest.is_a?(Name) && desc.classification.present?
          begin
            Name.validate_classification(dest.rank, desc.classification)
          rescue StandardError => e
            flash_error(:runtime_description_move_invalid_classification.t)
            flash_error(e.to_s)
            desc.classification = ""
          end
        end

        # Okay, *now* we can try to save the new description...
        if desc.save
          dest.log(:log_description_created,
                   user: @user.login,
                   name: desc.unique_partial_format_name,
                   touch: true)
          flash_notice(:runtime_description_copy_success.
                       t(old: src_title, new: desc.format_name))
          redirect_with_query(action: desc.show_action, id: desc.id)
        else
          flash_object_errors(desc)
        end
      end
    end

    # Tentatively merge the fields by sticking src's notes after dest's wherever
    # there is a conflict.  Give user a chance to merge them by hand.
    def merge_description_notes(src, dest)
      src_notes  = src.all_notes
      dest_notes = dest.all_notes
      src_notes.each_key do |f|
        if dest_notes[f].blank?
          dest_notes[f] = src_notes[f]
        elsif src_notes[f].present?
          dest_notes[f] += "\n\n--------------------------------------\n\n"
          dest_notes[f] += src_notes[f].to_s
        end
      end
      dest.all_notes = dest_notes
    end

    # Attempt to merge one description into another, deleting the old one
    # if requested.  It will only do so if there is no conflict on any of the
    # description fields, i.e. one or the other is blank for any given field.
    def perform_merge(src, dest, delete_after)
      src_notes  = src.all_notes
      dest_notes = dest.all_notes
      result = false

      # Mergeable if there are no fields which are non-blank in both descriptions.
      if src.class.all_note_fields.none? \
           { |f| src_notes[f].present? && dest_notes[f].present? }
        result = true

        # Copy over all non-blank descriptive fields.
        src_notes.each do |f, val|
          dest.send("#{f}=", val) if val.present?
        end

        # Save changes to destination.
        dest.save

        # Copy over authors and editors.
        src.authors.each { |user| dest.add_author(user) }
        src.editors.each { |user| dest.add_editor(user) }

        # Delete old description if requested.
        if delete_after
          if !in_admin_mode? && !src.is_admin?(@user)
            flash_warning(:runtime_description_merge_delete_denied.t)
          else
            src_was_default = (src.parent.description_id == src.id)
            flash_notice(:runtime_description_merge_deleted.
                           t(old: src.unique_partial_format_name))
            src.destroy

            # Make destination the default if source used to be the default.
            if src_was_default && dest.fully_public
              dest.parent.description = dest
              dest.parent.save
            end
          end
        end

      end
      result
    end

    include ::Descriptions
  end
end
