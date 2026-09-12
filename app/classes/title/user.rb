# frozen_string_literal: true

# Both the page heading and the browser tab title use the
# "About <Full Name (login)>" i18n template — the "About" prefix
# is the show-page's identity (vs. e.g. an edit page).
class Title::User < Title
  def page_title(_user = nil)
    :show_user_about.t(user: @object.unique_text_name)
  end

  def document_title
    :show_user_about.t(user: @object.unique_text_name)
  end
end
