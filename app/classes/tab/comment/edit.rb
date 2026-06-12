# frozen_string_literal: true

# "Edit comment" link.
class Tab::Comment::Edit < Tab::Base
  def initialize(comment:)
    super()
    @comment = comment
  end

  def title
    :comment_show_edit.t
  end

  def path
    edit_comment_path(@comment.id)
  end

  def html_options
    { icon: :edit }
  end

  def model
    @comment
  end
end
