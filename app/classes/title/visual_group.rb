# frozen_string_literal: true

# Page heading (textile applied) + browser tab title (plain `name`).
class Title::VisualGroup < Title
  def page_title(_user = nil)
    @object.name.t
  end

  def document_title
    @object.name
  end
end
