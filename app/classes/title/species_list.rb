# frozen_string_literal: true

# Page heading + browser tab title — both plain `title`.
class Title::SpeciesList < Title
  def page_title(_user = nil)
    @object.title
  end

  def document_title
    @object.title
  end
end
