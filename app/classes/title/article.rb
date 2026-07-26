# frozen_string_literal: true

# Page heading: bold-textile + `.t` (HTML). Doc title: plain title.
class Title::Article < Title
  def page_title(_user = nil)
    @object.display_title.t
  end

  def document_title
    @object.title
  end
end
