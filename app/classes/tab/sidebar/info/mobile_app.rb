# frozen_string_literal: true

# Sidebar info nav: mobile-app article.
class Tab::Sidebar::Info::MobileApp < Tab::Base
  def title
    :app_mobile.t
  end

  def path
    article_path(34)
  end
end
