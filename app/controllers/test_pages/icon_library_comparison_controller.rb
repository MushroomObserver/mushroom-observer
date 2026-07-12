# frozen_string_literal: true

module TestPages
  # Dummy comparison page: renders every semantic icon MO currently uses
  # (Components::Icon::GLYPHS) at large size, next to a candidate
  # equivalent from Bootstrap Icons and from Font Awesome Free, so the
  # team can visually pick a replacement library for the Bootstrap 3
  # Glyphicons. See GH issue #3797. Delete this whole test page once
  # the library is chosen.
  class IconLibraryComparisonController < ApplicationController
    before_action :login_required

    def show
      render(Views::Controllers::TestPages::IconLibraryComparison::Show.new)
    end
  end
end
