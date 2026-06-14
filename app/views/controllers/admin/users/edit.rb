# frozen_string_literal: true

module Views::Controllers::Admin::Users
  # Change-user-bonuses page. Title + BonusesForm component.
  class Edit < Views::Base
    prop :user2, ::User
    prop :user_stats, ::UserStats

    def view_template
      add_page_title(:change_user_bonuses_title.t(user: @user2.legal_name))
      render(BonusesForm.new(@user_stats))
    end
  end
end
