# frozen_string_literal: true

# Sibling of `Observations::DisplayNameBriefAuthorsLink` — same
# pattern but without authority abbreviations
# (`user_display_name_without_authors`). Used for the
# preferred-synonym slot in the obs-title chain.
class Observations::DisplayNameWithoutAuthorsLink
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
      @name.user_display_name_without_authors(@user).t,
      ::Rails.application.routes.url_helpers.name_path(id: @name.id),
      **@options
    )
  end
end
