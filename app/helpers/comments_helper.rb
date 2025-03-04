# frozen_string_literal: true

module CommentsHelper
  # The new_comment_tab now has an icon. icon buttons send icon: true
  def new_comment_link(object, btn_class: "btn btn-default btn-sm", icon: false)
    name, path, args = *new_comment_tab(object, btn_class: btn_class)
    args = args.merge({ icon: nil }) unless icon

    modal_link_to("comment", name, path, args)
  end
end
