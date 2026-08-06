# frozen_string_literal: true

module TestPages
  # Dummy comparison page: for every Components::Icon::GLYPHS entry,
  # renders the current Bootstrap 3 Glyphicon next to its candidate
  # replacement(s) in the licensed Glyphicons 2.0 sprites (basic and
  # halflings, when both offer a version), so the team can pick which
  # sprite variant to use per icon. See GH issue #3797. Delete this
  # whole test page once the picks are locked in.
  class IconSpriteComparisonController < ApplicationController
    before_action :login_required

    def show
      render(Views::Controllers::TestPages::IconSpriteComparison::Show.new)
    end
  end
end
