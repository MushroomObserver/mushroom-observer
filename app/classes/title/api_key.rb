# frozen_string_literal: true

# Falls back to the key string when notes are blank, so a freshly
# created key with no notes yet still gets a non-empty heading.
class Title::APIKey < Title
  def page_title(_user = nil)
    title_text
  end

  def document_title
    title_text
  end

  private

  def title_text
    @object.notes.presence || @object.key
  end
end
