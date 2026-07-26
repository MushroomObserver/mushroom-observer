# frozen_string_literal: true

# Page heading: textilize so apostrophes etc. become smart-quoted
# (and bold/italic markers, if any user typed them into the name,
# render correctly). Doc title is plain `format_name` — the browser
# tab doesn't render HTML or smart-quote.
class Title::Herbarium < Title
  def page_title(_user = nil)
    @object.format_name.t
  end

  def document_title
    @object.format_name
  end
end
