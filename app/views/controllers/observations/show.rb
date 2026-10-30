# frozen_string_literal: true

# Main observation show page — the parent that composes every
# obs-show sub-panel (`Components::ImageGallery`,
# `Details`, `NameInfoPanel`, `SpeciesListsPanel`, `ProjectsPanel`,
# `MatchingObservationsPanel`, namings partial, comments partial,
# `Views::Layouts::ObjectFooter`) into a two-column layout.
#
# Renders `add_show_title` (with the owner-naming line) + pager /
# interest / edit icons (logged-in only) into the page chrome, then
# one `.row`: the wide left column (carousel, namings, comments) and
# the narrow right column (details + the rest). The two columns keep
# the same relative order on mobile (Bootstrap stacks the whole left
# column, then the whole right column), except Details, which
# belongs right after the carousel on mobile instead of first in the
# right column — the `obs-show-layout` Stimulus controller
# (`app/javascript/controllers/obs-show-layout_controller.js`)
# relocates that one element across the `md` breakpoint; everything
# else needs no JS.
#
# `owner_naming_line` is now `Observations::OwnerNamingLine`;
# `link_to_display_name_brief_authors` is now
# `Observations::DisplayNameBriefAuthorsLink`. The PORO callsites
# are inside `add_show_title`'s `owner_naming:` handling
# (`title_helper.rb`) and the obs-title chain in
# `observations_helper.rb`.
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
      render_body_row
      render_footer if @user
    end

    private

    def add_chrome
      add_show_title(@observation, user: @user, owner_naming: true)
      if @user
        add_pager_for(@observation)
        add_interest_icons(@user, @observation)
        add_edit_icons(@observation, @user)
      end
      container_class(:double)
      column_classes(:eight_four)
    end

    # ---- one row, two independently-flowing columns ----
    # See class comment -- `obs-show-layout` moves Details across
    # the `md` breakpoint; everything else needs no JS.

    def render_body_row
      Row(data: { controller: "obs-show-layout" }) do
        div(class: content_for(:left_columns)) { render_left_column }
        div(class: content_for(:right_columns),
            data: { obs_show_layout_target: "rightColumn" }) do
          render_right_column
        end
      end
    end

    def render_left_column
      render_carousel_cell
      render_namings if @user
      render_comments
    end

    def render_carousel_cell
      div(data: { obs_show_layout_target: "carousel" }) { render_carousel }
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

    def render_right_column
      render_details_cell
      render_user_only_right_column_panels if @user
      render(NotesPanel.new(obs: @observation, user: @user))
    end

    def render_details_cell
      div(data: { obs_show_layout_target: "details" }) { render_details }
    end

    def render_details
      render(Details.new(
               obs: @observation, consensus: @consensus, user: @user,
               sites: @other_sites, siblings: @sibling_observations
             ))
    end

    def render_user_only_right_column_panels
      render(SpecimenPanel.new(
               obs: @observation, user: @user,
               siblings: @sibling_observations
             ))
      render(NameInfoPanel.new(obs: @observation, user: @user))
      render(SpeciesListsPanel.new(obs: @observation, user: @user))
      render(ProjectsPanel.new(obs: @observation, user: @user))
      render(MatchingObservationsPanel.new(
               obs: @observation, occurrence: @occurrence,
               siblings: @sibling_observations
             ))
    end

    def render_footer
      render(Views::Layouts::ObjectFooter.new(user: @user, obj: @observation))
    end
  end
end
