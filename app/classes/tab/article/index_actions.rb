# frozen_string_literal: true

# Action-nav for the articles index page. New-article link only
# shows when the viewer can create articles.
class Tab::Article::IndexActions < Tab::Collection
  def initialize(user:)
    super()
    @user = user
  end

  private

  def tabs
    return [] unless Article.can_edit?(@user)

    [Tab::Article::New.new]
  end
end
