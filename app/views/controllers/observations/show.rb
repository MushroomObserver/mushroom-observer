# frozen_string_literal: true

# Main observation show page — the parent that composes every
# obs-show sub-panel (`Components::Carousel`,
# `ObservationDetailsPanel`, `NameInfoPanel`, `SpeciesListsPanel`,
# `AssociatedObservationsPanel`, `ThumbnailMapPanel`, namings
# partial, comments partial, `Components::ObjectFooter`) into a
# two-column layout. Replaces `observations/show.html.erb`.
#
# Renders `add_show_title` + owner-naming line + pager / interest /
# edit icons (logged-in only) into the page chrome, then a `.row`
# with the carousel on the left and observation details / name
# info / species lists / matching obs on the right. Second `.row`
# below: namings table + comments on the left, thumbnail map on
# the right (logged-in only).
#
# Inlines `ObservationsHelper#owner_naming_line` +
# `#owner_preferred_naming` (only callsites lived in this template);
# `link_to_display_name_brief_authors` stays registered (used
# widely).
module Views::Controllers::Observations
  class Show < Views::Base
    register_value_helper :add_owner_naming
    register_value_helper :link_to_display_name_brief_authors
    register_output_helper :flash_notices_html, mark_safe: true
    # `tpl` on a SafeBuffer goes through MO's textile path; needed
    # for `@observation.source_credit.tpl` below. Not a Phlex
    # primitive — calling on the model's String return value
    # already works.

    # rubocop:disable Metrics/ParameterLists
    # The show page consumes every obs-derived ivar the controller
    # builds; the param list mirrors the controller's `@ivar`s.
    def initialize(observation:, user: nil, consensus: nil,
                   comments: [], images: [], other_sites: nil,
                   sibling_observations: nil, occurrence: nil,
                   owner_name: nil)
      super()
      @observation = observation
      @user = user
      @consensus = consensus
      @comments = comments
      @images = images
      @other_sites = other_sites
      @sibling_observations = sibling_observations || []
      @occurrence = occurrence
      @owner_name = owner_name
    end
    # rubocop:enable Metrics/ParameterLists

    def view_template
      add_chrome
      render(Views::Controllers::Observations::ImportedSourceBanner.new(
               observation: @observation
             ))
      render_main_row
      render_secondary_row
      render_footer if @user
    end

    private

    def add_chrome
      add_show_title(@observation, user: @user)
      add_owner_naming(owner_naming_line)
      if @user
        add_pager_for(@observation)
        add_interest_icons(@user, @observation)
        add_edit_icons(@observation, @user)
      end
      container_class(:double)
      column_classes(:eight_four)
    end

    # Inlined from `ObservationsHelper#owner_naming_line` (+
    # `#owner_preferred_naming`). Returns `nil` when the obs's
    # owner hasn't proposed a different name than the current
    # consensus, or when the viewer hasn't opted in to seeing
    # owner IDs.
    def owner_naming_line
      return unless @user&.view_owner_id && @owner_name &&
                    @owner_name.id != @observation.name.id

      link = link_to_display_name_brief_authors(
        @user, @owner_name,
        class: "obs_owner_naming_link_#{@owner_name.id}"
      )
      [link.t, "(#{:show_observation_owner_id.l})"].safe_join(" ")
    end

    # ---- main row: carousel | obs details / name / lists -----

    def render_main_row
      div(class: "row") do
        div(class: content_for(:left_columns)) { render_carousel }
        div(class: content_for(:right_columns)) { render_right_column }
      end
    end

    def render_carousel
      render(Components::Carousel.new(
               object: @observation, images: @images,
               carousel_id: "observation_images", user: @user,
               title: :IMAGES.t, links: carousel_links
             ))
    end

    def carousel_links
      return "" unless permission?(@observation)

      content, path, opts = ::Tab::Observation::ReuseImages.new(
        observation: @observation
      ).to_a
      capture { render(Components::IconLink.new(content, path, **opts)) }
    end

    def render_right_column
      render(ObservationDetailsPanel.new(
               obs: @observation, consensus: @consensus, user: @user,
               sites: @other_sites&.to_a, siblings: @sibling_observations
             ))
      return unless @user

      render(NameInfoPanel.new(obs: @observation, user: @user))
      render(SpeciesListsPanel.new(obs: @observation, user: @user))
      render(AssociatedObservationsPanel.new(
               obs: @observation, occurrence: @occurrence,
               siblings: @sibling_observations, user: @user
             ))
    end

    # ---- secondary row: namings + comments | thumbnail map ----

    def render_secondary_row
      div(class: "row") do
        div(class: content_for(:left_columns)) do
          render_namings_and_comments
        end
        if @user
          div(class: content_for(:right_columns)) do
            render_thumbnail_map_if_shown
          end
        end
      end
    end

    def render_namings_and_comments
      render_namings if @user
      render_comments
      render_source_credit if show_source_credit?
    end

    # `_namings.erb` is still ERB (the namings table includes
    # turbo-driven update logic that hasn't been Phlexified yet —
    # `Observations::Namings::VotesController` feeds it via the
    # `_section_update.erb` dispatcher).
    def render_namings
      trusted_html(
        view_context.render(
          partial: "observations/show/namings",
          locals: { obs: @observation, consensus: @consensus, user: @user }
        )
      )
    end

    # Same situation for `_comments_for_object.erb` — separate
    # subsystem (Comments), separate conversion PR.
    def render_comments
      trusted_html(
        view_context.render(
          partial: "comments/comments_for_object",
          locals: { object: @observation, comments: @comments,
                    controls: @user, limit: nil }
        )
      )
    end

    def show_source_credit?
      @observation.source_noteworthy? && !@observation.external_source
    end

    def render_source_credit
      trusted_html(@observation.source_credit.tpl)
    end

    def render_thumbnail_map_if_shown
      return unless show_thumbnail_map?

      render(ThumbnailMapPanel.new(
               obs: @observation, user: @user
             ))
    end

    # Only called from inside the `if @user` branch of
    # `render_secondary_row`, so `@user` is always truthy here.
    # The legacy ERB computed a `show_map` value with a
    # `!@user`-then-session fallback, but the value was only used
    # inside its own `if @user` block — the fallback branch was
    # never reachable. Mirror reality.
    def show_thumbnail_map?
      @user.thumbnail_maps
    end

    def render_footer
      render(Components::ObjectFooter.new(user: @user, obj: @observation))
    end
  end
end
