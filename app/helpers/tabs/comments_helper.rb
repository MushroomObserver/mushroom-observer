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
      return unless permission?(comment)

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

    def new_comment_tab(object, btn_class: nil)
      InternalLink::Model.new(
        :show_comments_add_comment.l, object,
        new_comment_path(target: object.id, type: object.class.name),
        html_options: { class: btn_class, icon: :add }
      ).tab
    end

    def edit_comment_tab(comment)
      InternalLink::Model.new(
        :comment_show_edit.t, comment,
        edit_comment_path(comment.id),
        html_options: { icon: :edit }
      ).tab
    end

    def destroy_comment_tab(comment)
      InternalLink::Model.new(
        :comment_show_destroy.t, comment, comment,
        html_options: { button: :destroy }
      ).tab
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
