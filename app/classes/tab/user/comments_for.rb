# frozen_string_literal: true

# "Comments for this user" link. Title defaults to "Comments for
# {name}"; callers pass `text:` to override.
class Tab::User::CommentsFor < Tab::Base
  def initialize(user:, text: nil)
    super()
    @user = user
    @text = text
  end

  def title
    @text || :show_user_comments_for.t(name: @user.text_name)
  end

  def path
    comments_path(for_user: @user.id)
  end

  def model
    @user
  end
end
