# frozen_string_literal: true

# Sidebar latest nav: comments index. User-only.
class Tab::Sidebar::Latest::Comments < Tab::Base
  def title
    :app_comments.t
  end

  def path
    comments_path
  end

  def html_options
    { id: "nav_comments_link" }
  end
end
