# frozen_string_literal: true

# Sidebar admin nav: edit banner page.
class Tab::Sidebar::Admin::Banners < Tab::Base
  def title
    :change_banner_title.t
  end

  def path
    admin_banners_path
  end
end
