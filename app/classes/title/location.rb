# frozen_string_literal: true

# Page heading + browser tab title. `display_name` is plain text for
# the visible heading (place name; no textile); `text_name` is the
# ASCII form for the doc title.
class Title::Location < Title
  def page_title(user = nil)
    @object.display_name(user)
  end

  def document_title
    @object.text_name
  end
end
