# frozen_string_literal: true

# Main observation show page — the parent that composes every
# obs-show sub-panel (`Components::ImageGallery`,
# `Details`, `NameInfoPanel`, `SpeciesListsPanel`, `ProjectsPanel`,
# `MatchingObservationsPanel`, namings partial, comments partial,
# `Views::Layouts::ObjectFooter`) into a two-column layout.
#
# Renders `add_show_title` + owner-naming line + pager / interest /
# edit icons (logged-in only) into the page chrome, then a `.row`
# with the carousel on the left and observation details / name
# info / species lists / projects / matching obs on the right.
# Second `.row` below: namings table + comments on the left,
# notes panel on the right.
#
# `owner_naming_line` is now `Observations::OwnerNamingLine`;
# `link_to_display_name_brief_authors` is now
# `Observations::DisplayNameBriefAuthorsLink`. The PORO callsites
# are inside `add_owner_naming` (`title_helper.rb`) and the
# obs-title chain in `observations_helper.rb`.
module Views::Controllers::Observations
  class Show < Views::FullPageBase
    prop :observation, ::Observation
    prop :user, _Nilable(::User), default: nil
    prop :consensus, _Nilable(::Observation::NamingConsensus), default: nil
    prop :comments, _Array(::Comment), default: -> { [] }
    prop :images, _Array(::Image), default: -> { [] }
    prop :other_sites, _Nilable(_Array(::ExternalSite)), default: nil
    prop :sibling_observations, _Array(::Observation)
    prop :occurrence, _Nilable(::Occurrence), default: nil
    prop :owner_name, _Nilable(::Name), default: nil

    # sibling_observations: only gets computed by the controller when
    # there's an @occurrence -- normalize nil to [] here so callers
    # (and this class's own methods) never need a nil-guard.
    def initialize(sibling_observations: nil, **)
      super(sibling_observations: sibling_observations || [], **)
    end

    def view_template
      add_chrome
      # Any member of an occurrence with a reflection can get a resync
      # broadcast (#4215) -- the aggregate flash goes to every member's
      # channel. See Inat::ObservationResyncer#broadcast.
      turbo_stream_from([@observation, :external_link_sync]) if
        @observation.syncable?
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
      Row do
        div(class: content_for(:left_columns)) { render_carousel }
        div(class: content_for(:right_columns)) { render_right_column }
      end
    end

    def render_carousel
      ImageGallery(
        object: @observation, images: @images,
        carousel_id: "observation_images", user: @user,
        title: :images.ti, links: carousel_links
      )
    end

    def carousel_links
      return "" unless permission?(@observation)

      capture do
        Link(type: :get,
             tab: ::Tab::Observation::ReuseImages.new(
               observation: @observation
             ))
      end
    end

    def render_right_column
      render(Details.new(
               obs: @observation, consensus: @consensus, user: @user,
               sites: @other_sites, siblings: @sibling_observations
             ))
      return unless @user

      render(SpecimenPanel.new(
               obs: @observation, user: @user,
               siblings: @sibling_observations
             ))
      render(NameInfoPanel.new(obs: @observation, user: @user))
      render(SpeciesListsPanel.new(obs: @observation, user: @user))
      render(ProjectsPanel.new(obs: @observation))
      render(MatchingObservationsPanel.new(
               obs: @observation, occurrence: @occurrence,
               siblings: @sibling_observations
             ))
    end

    # ---- secondary row: namings + comments | notes ----

    def render_secondary_row
      Row do
        div(class: content_for(:left_columns)) do
          render_namings_and_comments
        end
        div(class: content_for(:right_columns)) do
          render(NotesPanel.new(obs: @observation, user: @user))
        end
      end
    end

    def render_namings_and_comments
      render_namings if @user
      render_comments
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

    def render_footer
      render(Views::Layouts::ObjectFooter.new(user: @user, obj: @observation))
    end
  end
end
