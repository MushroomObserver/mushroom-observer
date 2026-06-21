# frozen_string_literal: true

# "Add comment" link. `object` is the target the comment will be
# attached to (Observation, Project, etc.).
class Tab::Comment::New < Tab::Base
  def initialize(object:)
    super()
    @object = object
  end

  def title
    :show_comments_add_comment.l
  end

  def path
    new_comment_path(target: @object.id, type: @object.class.name)
  end

  def html_options
    { icon: :add }
  end

  def model
    @object
  end
end
