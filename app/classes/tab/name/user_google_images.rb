# frozen_string_literal: true

# "Google Images" external-site link for a Name. Composes the
# query string from `name.user_real_text_name(user)` — different
# users may see different real_text_name strings depending on
# preferences (synonyms / sub-taxa expansion).
class Tab::Name::UserGoogleImages < Tab::Name::ExternalBase
  def initialize(name:, user:)
    super(name: name)
    @user = user
  end

  def title
    :google_images.t
  end

  def path
    format("https://images.google.com/images?q=%s",
           @name.user_real_text_name(@user))
  end
end
