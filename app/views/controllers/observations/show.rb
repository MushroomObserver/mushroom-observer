# frozen_string_literal: true

# Main observation show page — the parent that composes every
# obs-show sub-panel (`Components::Carousel`,
# `ObservationDetailsPanel`, `NameInfoPanel`, `SpeciesListsPanel`,
# `AssociatedObservationsPanel`, `ThumbnailMapPanel`, namings
# partial, comments partial, `Views::Layouts::VersionsFooter`) into a
# two-column layout. Replaces `observations/show.html.erb`.
#
# Renders `add_show_title` + owner-naming line + pager / interest /
# edit icons (logged-in only) into the page chrome, then a `.row`
# with the carousel on the left and observation details / name
# info / species lists / matching obs on the right. Second `.row`
# below: namings table + comments on the left, thumbnail map on
# the right (logged-in only).
#
# `owner_naming_line` is now `Observations::OwnerNamingLine`;
# `link_to_display_name_brief_authors` is now
# `Observations::DisplayNameBriefAuthorsLink`. The PORO callsites
# are inside `add_owner_naming` (`title_helper.rb`) and the
# obs-title chain in `observations_helper.rb`.
module Views::Controllers::Observations
  class Show < Views::Base
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
      add_owner_naming(observation: @observation, user: @user)
      if @user
        add_pager_for(@observation)
        add_interest_icons(@user, @observation)
        add_edit_icons(@observation, @user)
      end
      container_class(:double)
      column_classes(:eight_four)
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

      capture do
        render(Components::IconLink.new(
                 tab: ::Tab::Observation::ReuseImages.new(
                   observation: @observation
                 )
               ))
      end
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
               siblings: @sibling_observations
             ))
    end

    # ---- secondary row: namings + comments | thumbnail map ----

    def render_secondary_row
      div(class: "row") do
        div(class: content_for(:left_columns)) do
          render_namings_and_comments
        end
        div(class: content_for(:right_columns)) do
          if @user&.thumbnail_maps
            render(ThumbnailMapPanel.new(obs: @observation))
          end
        end
      end
    end

    def render_namings_and_comments
      render_namings if @user
      render_comments
      render_source_credit if show_source_credit?
    end

    def render_namings
      render(Namings.new(obs: @observation, user: @user,
                         consensus: @consensus))
    end

    def render_comments
      render(::Views::Controllers::Comments::CommentsForObject.new(
               object: @observation, comments: @comments.to_a, user: @user,
               editable: @user.present?, limit: nil
             ))
    end

    def show_source_credit?
      @observation.source_noteworthy? && !@observation.external_source
    end

    def render_source_credit
      trusted_html(@observation.source_credit.tpl)
    end

    def render_footer
      render(Views::Layouts::VersionsFooter.new(user: @user, obj: @observation))
    end
  end
end
