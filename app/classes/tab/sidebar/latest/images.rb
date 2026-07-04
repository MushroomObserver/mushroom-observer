# frozen_string_literal: true

# Sidebar latest nav: newest images. User-only.
class Tab::Sidebar::Latest::Images < Tab::Base
  def title
    :app_newest_images.t
  end

  def path
    images_path
  end
end
