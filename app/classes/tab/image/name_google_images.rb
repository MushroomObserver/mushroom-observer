# frozen_string_literal: true

# "Google Images" external-site link used on the image show page —
# searches by `name.search_name` (not user-aware), distinct from
# `Tab::Name::UserGoogleImages` (which uses `name.real_text_name(user)`).
class Tab::Image::NameGoogleImages < Tab::Base
  def initialize(name:)
    super()
    @name = name
  end

  def title
    :google_images.t
  end

  def path
    "http://images.google.com/images?q=#{@name.search_name}"
  end

  def html_options
    { external: true }
  end
end
