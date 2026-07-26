# frozen_string_literal: true

# Page heading + browser tab title — `format_name` is plain text
# (collector "name number"). The page-title side applies `.t` to keep
# the binomial-in-name italicized.
class Title::CollectionNumber < Title
  def page_title(_user = nil)
    @object.format_name.t
  end

  def document_title
    @object.format_name
  end
end
