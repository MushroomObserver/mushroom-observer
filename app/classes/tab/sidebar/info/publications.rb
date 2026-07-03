# frozen_string_literal: true

# Sidebar info nav: publications index.
class Tab::Sidebar::Info::Publications < Tab::Base
  def title
    :app_publications.t
  end

  def path
    publications_path
  end
end
