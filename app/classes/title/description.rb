# frozen_string_literal: true

# Page heading: textilized parent-inclusive name. Doc title: plain
# (Description#text_name already strips HTML/textile down to ASCII).
class Title::Description < Title
  def page_title(_user = nil)
    @object.format_name.t
  end

  def document_title
    @object.text_name
  end
end
