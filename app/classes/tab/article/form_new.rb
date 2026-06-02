# frozen_string_literal: true

# Action-nav for the article new form.
class Tab::Article::FormNew < Tab::Collection
  private

  def tabs
    [Tab::Article::Index.new]
  end
end
