# frozen_string_literal: true

# helpers for Support controller and views
module SupportHelper
  def init_navbar(links = nil )
    { title: { title: :SUPPORT.t, url: support_donate_path }, links: links }
  end

  def donors_navbar
    links = [
      { title: :donors_tab.t, url: support_donors_path,
        icon: "fa-user-friends" }
    ]
    if in_admin_mode?
      links << [
        { title: :create_donation_tab.t, url: support_create_donation_path,
          icon: "fa-donate" },
        { title: :review_donations_tab.t, url: support_review_donations_path,
          icon: "fa-clipboard-list" }
      ]
    end
    init_navbar(links)
  end

  def default_links
    [
      { title: :donate_tab.t, url: support_donate_path,
        icon: "fa-helping-hands" },
      { title: :donors_tab.t, url: support_donors_path,
        icon: "fa-user-friends" }
    ].freeze
  end
end
