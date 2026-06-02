# frozen_string_literal: true

module UsersHelper
  def users_index_sorts(admin: false)
    return admin_users_index_sorts if admin

    regular_users_index_sorts
  end

  def regular_users_index_sorts
    [
      ["login",        :sort_by_login.t],
      ["name",         :sort_by_name.t],
      ["created_at",   :sort_by_created_at.t],
      ["location",     :sort_by_location.t],
      ["contribution", :sort_by_contribution.t]
    ].freeze
  end

  def admin_users_index_sorts
    [
      ["id",           :sort_by_id.t],
      ["login",        :sort_by_login.t],
      ["name",         :sort_by_name.t],
      ["created_at",   :sort_by_created_at.t],
      ["updated_at",   :sort_by_updated_at.t],
      ["last_login",   :sort_by_last_login.t],
      ["contribution", :sort_by_contribution.t]
    ].freeze
  end
end
