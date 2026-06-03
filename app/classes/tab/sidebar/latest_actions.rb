# frozen_string_literal: true

# Sidebar "Latest" section. News is always shown; user-only items
# (changes / images / comments) only when a user is logged in.
class Tab::Sidebar::LatestActions < Tab::Collection
  def initialize(user: nil)
    super()
    @user = user
  end

  private

  def tabs
    base = [Tab::Sidebar::Latest::News.new]
    return base unless @user

    base + [Tab::Sidebar::Latest::Changes.new,
            Tab::Sidebar::Latest::Images.new,
            Tab::Sidebar::Latest::Comments.new]
  end
end
