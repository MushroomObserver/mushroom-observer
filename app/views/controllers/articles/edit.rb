# frozen_string_literal: true

module Views::Controllers::Articles
  # Action template for the edit-article page. Page chrome (title,
  # context-nav) + the shared `Form` component.
  class Edit < Views::Base
    prop :article, ::Article

    def view_template
      add_edit_title(@article)
      add_context_nav(::Tab::Article::FormEdit.new(article: @article))
      render(Form.new(@article))
    end
  end
end
