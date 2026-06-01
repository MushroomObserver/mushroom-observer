# frozen_string_literal: true

module CommentsHelper
  # The new_comment_tab now has an icon. icon buttons send icon: true
  def new_comment_link(object, btn_class: "btn btn-default btn-sm", icon: false)
    name, path, args = *Tab::Comment::New.new(
      object: object, btn_class: btn_class
    ).to_a
    args = args.merge({ icon: nil }) unless icon

    modal_link_to("comment", name, path, args)
  end

  def comments_index_sorts
    [
      ["user",       :sort_by_user.t],
      ["created_at", :sort_by_posted.t],
      ["updated_at", :sort_by_updated_at.t]
    ].freeze
  end
end
