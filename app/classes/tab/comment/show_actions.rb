# frozen_string_literal: true

# Action-nav on the comment show page: return to target + (if the
# viewer can edit) edit/destroy.
class Tab::Comment::ShowActions < Tab::Collection
  def initialize(comment:, target:, permission: false)
    super()
    @comment = comment
    @target = target
    @permission = permission
  end

  private

  def tabs
    base = [
      Tab::Object::Return.new(
        object: @target,
        title: :comment_show_show.t(type: @comment.target_type_localized)
      )
    ]
    return base unless @permission

    base + [
      Tab::Comment::Edit.new(comment: @comment),
      Tab::Comment::Destroy.new(comment: @comment)
    ]
  end
end
