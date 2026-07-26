# frozen_string_literal: true

# Page heading (rendered HTML — textile applied + author wrapping).
# `user` arg lets us respect hide_authors prefs. When nil we use the
# raw display_name (no user-specific transforms).
class Title::Name < Title
  def page_title(user = nil)
    @object.display_name(user).t.small_author
  end

  # Plain-text title for the browser tab `<title>`. Helper prepends
  # the type-tag + id; `text_name` is the binomial-only column.
  def document_title
    @object.text_name
  end
end
