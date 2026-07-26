# frozen_string_literal: true

# Page heading (rendered HTML — textile applied + author wrapping).
# User arg is ignored — images aggregate multiple obs's names, no
# single user preference applies.
class Title::Image < Title
  def page_title(_user = nil)
    @object.format_name.t.small_author
  end

  # Plain-text title for the browser tab `<title>`. Mirrors
  # `unique_text_name` but without the trailing "(<id>)" — the title
  # helper prepends "IMAGE <id>:" so we'd otherwise duplicate the id.
  def document_title
    @object.title_subjects(:text_name).presence || :image.l
  end
end
