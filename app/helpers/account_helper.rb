# frozen_string_literal: true

module AccountHelper
  def account_welcome_title(user = nil)
    if user
      :email_welcome.t(user: user.legal_name)
    else
      :welcome_no_user_title.t
    end
  end
end
