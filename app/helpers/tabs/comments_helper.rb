# frozen_string_literal: true

module Tabs
  module CommentsHelper
    def comment_show_tabs(comment:, target:)
      links = [
        object_return_tab(
          target,
          :comment_show_show.t(type: comment.target_type_localized)
        )
      ]
      return unless check_permission(comment)

      links += comment_mod_tabs(comment)
      links
    end

    def comment_form_new_title(target:)
      :comment_add_title.t(name: target.unique_format_name)
    end

    def comment_form_new_tabs(target:)
      [object_return_tab(target)]
    end

    def comment_form_edit_title(target:)
      :comment_edit_title.t(name: target.unique_format_name)
    end

    def comment_form_edit_tabs(comment:)
      [object_return_tab(comment)]
    end

    def comment_mod_tabs(comment)
      [
        edit_comment_tab(comment),
        destroy_comment_tab(comment)
      ]
    end

    def new_comment_tab(object)
      [:show_comments_add_comment.l,
       add_query_param(
         new_comment_path(target: object.id, type: object.class.name)
       ),
       { class: class_names("#{tab_id(__method__.to_s)}_#{object.id}",
                            %w[btn btn-default btn-sm]) }]
    end

    def edit_comment_tab(comment)
      [:comment_show_edit.t,
       add_query_param(edit_comment_path(comment.id)),
       { class: tab_id(__method__.to_s) }]
    end

    def destroy_comment_tab(comment)
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
