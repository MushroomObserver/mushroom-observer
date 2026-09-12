# frozen_string_literal: true

# Page heading + browser tab title — both just `name`.
class Title::VisualModel < Title
  def page_title(_user = nil)
    @object.name
  end

  def document_title
    @object.name
  end
end
