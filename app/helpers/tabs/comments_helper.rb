# frozen_string_literal: true

module Tabs
  module CommentsHelper
    def comment_show_links(comment:, target:)
      links = [
        object_return_link(
          target,
          :comment_show_show.t(type: comment.target_type_localized)
        )
      ]
      return unless check_permission(comment)

      links += comment_mod_links(comment)
      links
    end

    def comment_form_new_links(target:)
      [object_return_link(target)]
    end

    def comment_form_edit_links(comment:)
      [object_return_link(comment)]
    end

    def comment_mod_links(comment)
      [
        edit_comment_link(comment),
        destroy_comment_link(comment)
      ]
    end

    def edit_comment_link(comment)
      [:comment_show_edit.t,
       add_query_param(edit_comment_path(comment.id)),
       { class: __method__.to_s }]
    end

    def destroy_comment_link(comment)
      [:comment_show_destroy.t, comment, { button: :destroy }]
    end

    def comments_index_sorts
      [
        # ["summary",  :sort_by_summary.t],
        ["user", :sort_by_user.t],
        ["created_at", :sort_by_posted.t],
        ["updated_at", :sort_by_updated_at.t]
      ].freeze
    end
  end
end
