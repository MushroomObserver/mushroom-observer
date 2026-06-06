# frozen_string_literal: true

# Wraps a `Name` in an `<a>` linking to its show page, with the
# display name rendered through textile (`.t.small_author`) so
# authority abbreviations get the small-caps treatment. Used in
# obs-show title chains (consensus name link, deprecated-synonym
# link, owner-preferred link) and slated for wider use as the
# project moves to component-based markup. Mirrors the
# `location_link` helper pattern — a value-returning method that
# produces an html-safe `<a>` tag.
#
# Extracted from `ObservationsHelper#link_to_display_name_brief_authors`
# (still calls into it for the helper-bound `link_to` /
# `name_path` reach).
class Observations::DisplayNameBriefAuthorsLink
  class << self
    def for(user:, name:, **options)
      new(user: user, name: name, options: options).call
    end
  end

  def initialize(user:, name:, options: {})
    @user = user
    @name = name
    @options = options
  end

  def call
    ::ApplicationController.helpers.link_to(
      @name.user_display_name_brief_authors(@user).t.small_author,
      ::Rails.application.routes.url_helpers.name_path(id: @name.id),
      **@options
    )
  end
end
