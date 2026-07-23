# frozen_string_literal: true

# "Create article" link.
class Tab::Article::New < Tab::Base
  def title
    :create_object.t(type: :article)
  end

  def path
    new_article_path
  end

  def model
    Article
  end
end
