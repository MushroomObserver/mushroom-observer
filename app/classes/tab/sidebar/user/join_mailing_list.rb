# frozen_string_literal: true

# Sidebar user nav: external "Join MO general mailing list" link.
class Tab::Sidebar::User::JoinMailingList < Tab::Base
  def title
    :app_join_mailing_list.t
  end

  def path
    "https://groups.google.com/forum/?fromgroups=#!forum/mo-general"
  end

  def html_options
    { id: "nav_join_mailing_list_link" }
  end
end
