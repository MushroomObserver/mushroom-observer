# frozen_string_literal: true

# Action-nav for the article edit form.
class Tab::Article::FormEdit < Tab::Collection
  def initialize(article:)
    super()
    @article = article
  end

  private

  def tabs
    [Tab::Object::Return.new(object: @article),
     Tab::Article::Index.new]
  end
end
