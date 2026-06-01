# frozen_string_literal: true

# "Destroy comment" button-tab.
class Tab::Comment::Destroy < Tab::Base
  def initialize(comment:)
    super()
    @comment = comment
  end

  def title
    :comment_show_destroy.t
  end

  def path
    @comment
  end

  def html_options
    { button: :destroy }
  end

  def model
    @comment
  end
end
