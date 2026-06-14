# frozen_string_literal: true

module Views::Controllers::Articles
  # Action template for the new-article page. Page chrome (title,
  # context-nav) + the shared `Form` component.
  class New < Views::Base
    prop :article, ::Article

    def view_template
      add_new_title(:create_object, :ARTICLE)
      add_context_nav(::Tab::Article::FormNew.new)
      render(Form.new(@article))
    end
  end
end
