# frozen_string_literal: true

# "Email this user a question" link.
class Tab::User::EmailQuestion < Tab::Base
  def initialize(user:)
    super()
    @user = user
  end

  def title
    :show_user_email_to.t(name: @user.unique_text_name)
  end

  def path
    new_question_for_user_path(@user.id)
  end

  def html_options
    { icon: :email }
  end

  def model
    @user
  end
end
