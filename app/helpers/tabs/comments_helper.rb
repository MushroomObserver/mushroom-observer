# frozen_string_literal: true

module Tabs
  module CommentsHelper
    def comment_show_links(comment:, target:)
      target_type = comment.target_type_localized
      links = [
        [:comment_show_show.t(type: target_type),
         add_query_param(target.show_link_args),
         { class: "comment_target_return_link" }]
      ]
      return unless check_permission(comment)

      links += comment_mod_links(comment)
      links
    end

    def comment_form_new_links(target:)
      [
        [:cancel_and_show.t(type: target.type_tag.upcase),
         add_query_param(target.show_link_args),
         { class: "comment_target_return_link" }]
      ]
    end

    def comment_form_edit_links(comment:)
      [
        [:cancel_and_show.t(type: :comment),
         add_query_param(comment.show_link_args),
         { class: "comment_return_link" }]
      ]
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
       { class: "edit_comment_link" }]
    end

    def destroy_comment_link(comment)
      [:comment_show_destroy.t, comment, { button: :destroy }]
    end
  end
end
