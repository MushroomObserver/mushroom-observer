# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::Namings::RowTest <
  ComponentTestCase
  def setup
    super
    @naming = namings(:coprinus_comatus_naming)
    @obs = @naming.observation
    @user = @naming.user
    @consensus = ::Observation::NamingConsensus.new(@obs)
    controller.instance_variable_set(:@user, @user)
  end

  # ---- outer structure -----------------------------------------------

  def test_row_carries_observation_naming_dom_id
    # The id is the Turbo Stream target for vote / mod-link
    # broadcasts — it has to be `observation_naming_<id>` so the
    # NamingsController / VotesController stream actions can find
    # the row to update.
    html = render_row

    assert_html(html, "div.row.naming-row" \
                      "#observation_naming_#{@naming.id}")
  end

  def test_renders_four_main_column_cells_plus_eyes_column
    # Layout pin: name / proposer / vote-tally / your-vote columns
    # sit inside the `col-sm-11`; the eyes icon column is the
    # narrow `col-sm-1`.
    html = render_row

    assert_html(html, ".col.col-sm-11 > .row > .col.col-sm-4")
    assert_html(html, ".col.col-sm-11 > .row > .col.col-sm-3", count: 2)
    assert_html(html, ".col.col-sm-11 > .row > .col.col-sm-2")
    assert_html(html, ".col-sm-1.d-none.d-sm-block")
  end

  # ---- name cell -----------------------------------------------------

  def test_renders_name_link_to_show_name_page
    html = render_row

    assert_html(html, "a[href='#{routes.name_path(id: @naming.name)}']")
  end

  def test_renders_inline_mod_links_for_naming_owner
    # `@user` owns the naming → inline-mod-links group (edit /
    # destroy) appears next to the name link.
    html = render_row

    assert_html(html, ".text-nowrap")
    assert_html(html, "a.edit_naming_link_#{@naming.id}")
  end

  def test_no_mod_links_for_non_owner
    # Non-owner viewer → InlineModLinks renders nothing, so the
    # wrapper `.text-nowrap` is also absent.
    other_user = users(:mary)
    controller.instance_variable_set(:@user, other_user)
    html = render_row(user: other_user)

    assert_no_html(html, "a.edit_naming_link_#{@naming.id}")
  end

  # ---- proposer cell -------------------------------------------------

  def test_renders_proposer_user_link
    # Selector class flows through from `Components::Link::Object::User`:
    # `user_link_<id>`. Mobile label "User:" prefixed so the cell
    # is readable when column headers are hidden on `xs`.
    html = render_row

    assert_html(html, "a.user_link_#{@user.id}")
    assert_html(html, "small.visible-xs-inline",
                text: "#{:show_namings_user.t}: ")
  end

  # ---- vote tally cell -----------------------------------------------

  def test_vote_tally_shows_no_votes_when_naming_has_none
    # New naming with no votes → "(no votes)" placeholder, no
    # vote-percent modal link.
    @naming.votes.destroy_all
    html = render_row

    assert_no_html(html, "a.vote-percent")
    assert_includes(html, :show_namings_no_votes.t)
  end

  def test_vote_tally_shows_percent_modal_link_when_votes_exist
    # With at least one vote the cell shows "<percent>% (<n>)".
    # The percent is a ModalLink — opens the per-user breakdown
    # modal via Stimulus `modal-toggle`.
    ::Vote.create!(naming: @naming, observation: @obs,
                   user: users(:mary), value: 2.0)
    @naming.reload
    html = render_row

    assert_html(html, "a.vote-percent")
    assert_html(html, "a[data-modal='modal_naming_votes_#{@naming.id}']")
    # vote-number span carries the count for JS / tests targeting
    # it (it gets updated in place after a vote turbo_stream).
    assert_html(html, "span.vote-number")
  end

  # ---- your-vote cell ------------------------------------------------

  def test_your_vote_cell_renders_votes_form
    # Pin the Votes::Form is rendered with the right naming id, so
    # downstream Stimulus controllers find the right target.
    html = render_row

    assert_html(html, "form#naming_vote_form_#{@naming.id}")
    assert_html(html, "select[name='vote[value]']")
  end

  # ---- eyes column ---------------------------------------------------

  def test_eyes_column_shows_consensus_eye_when_naming_is_consensus_favorite
    # Stub the consensus so `consensus_naming == primary`.
    @consensus.stub(:consensus_naming, @naming) do
      @consensus.stub(:owners_favorite?, false) do
        html = render_row

        assert_html(html, ".vote-icon-consensus")
        assert_no_html(html, ".vote-icon-yours")
      end
    end
  end

  def test_eyes_column_shows_yours_eye_when_users_favorite
    @consensus.stub(:owners_favorite?, true) do
      @consensus.stub(:consensus_naming, nil) do
        html = render_row

        assert_html(html, ".vote-icon-yours")
        assert_no_html(html, ".vote-icon-consensus")
      end
    end
  end

  def test_eyes_column_shows_both_eyes_when_applicable
    @consensus.stub(:owners_favorite?, true) do
      @consensus.stub(:consensus_naming, @naming) do
        html = render_row

        assert_html(html, ".vote-icon-yours")
        assert_html(html, ".vote-icon-consensus")
      end
    end
  end

  def test_eyes_column_empty_when_nothing_applies
    @consensus.stub(:owners_favorite?, false) do
      @consensus.stub(:consensus_naming, nil) do
        html = render_row

        assert_no_html(html, ".vote-icon-yours")
        assert_no_html(html, ".vote-icon-consensus")
      end
    end
  end

  # ---- reasons row ---------------------------------------------------

  def test_reasons_row_renders
    # The reasons live in a small-styled row under the four main
    # columns. Always rendered (empty when no reasons used), so
    # one assertion exercises the layout.
    html = render_row

    assert_html(html, ".naming-reasons.small")
  end

  # ---- MergedNaming paths --------------------------------------------

  # The Row branches on `naming.is_a?(MergedNaming)` in three spots:
  # `primary` / `local` / `user_vote` derived-state accessors, the
  # multi-proposer "Matching Observations" link, and the
  # source-labeled grouped reasons (`render_merged_reasons` +
  # `render_reasons_source_label`). These tests pin one MergedNaming
  # shape per branch by constructing the merged naming directly —
  # going through `NamingConsensus#merged_namings` adds composition
  # that obscures which branch is being exercised.

  def test_merged_naming_with_local_naming_renders_single_proposer
    # Local naming exists (a naming on @obs itself) →
    # `local_naming` returns it, `user` returns its user,
    # `multiple_proposers?` is false → single-proposer UserLink
    # cell (and the `primary` / `local` / `user_vote` accessors
    # all take the MergedNaming branch).
    local_naming = create_naming_on(@obs, user: @user)
    merged = ::Observation::MergedNaming.new([local_naming],
                                             observation: @obs)

    html = render_row(naming: merged)

    assert_html(html, "a.user_link_#{@user.id}")
    assert_includes(html, @user.login)
  end

  def test_merged_naming_with_multiple_proposers_renders_matching_obs_link
    # No local naming, multiple users across siblings →
    # `multiple_proposers?` true → "Matching Observations" link
    # to the occurrence page (replaces the single-UserLink cell).
    sibling_obs = wire_up_occurrence_with_sibling
    sibling_one = create_naming_on(sibling_obs, user: @user)
    sibling_two = create_naming_on(sibling_obs, user: users(:mary))
    merged = ::Observation::MergedNaming.new([sibling_one, sibling_two],
                                             observation: @obs)

    html = render_row(naming: merged)

    assert_html(
      html, "a[href='#{routes.occurrence_path(@obs.occurrence)}']",
      text: :show_observation_matching_observations.l
    )
  end

  def test_merged_naming_renders_grouped_reasons_with_source_labels
    # A sibling-obs naming with a used reason → `grouped_reasons`
    # yields `[[sibling_obs, [reason]]]` → `render_reasons_source_label`
    # emits the "From MO <id>:" link to the sibling observation.
    sibling_obs = wire_up_occurrence_with_sibling
    sibling_naming = create_naming_on(sibling_obs, user: @user,
                                                   used_reason: "Spotted it")
    merged = ::Observation::MergedNaming.new([sibling_naming],
                                             observation: @obs)

    html = render_row(naming: merged)

    assert_html(
      html,
      ".naming-reasons a[href='" \
      "#{routes.permanent_observation_path(sibling_obs.id)}']",
      text: "MO #{sibling_obs.id}"
    )
  end

  # ---- parity tests ------------------------------------------------

  class OldMatchingObsLink < Components::Base
    def initialize(url:, name:)
      super()
      @url = url
      @name = name
    end

    def view_template
      a(href: @url,
        class: "btn btn-link text-wrap text-left px-0") { plain(@name) }
    end
  end

  def test_matching_observations_link_parity
    url = "/occurrences/1"
    name = :show_observation_matching_observations.l

    old_html = render(OldMatchingObsLink.new(url: url, name: name))
    new_html = render(Components::Button::Get.new(
                        target: url,
                        name: name,
                        style: :link,
                        class: "text-wrap text-left px-0"
                      ))

    assert_html_element_equivalent(old_html, new_html,
                                   selector: "a",
                                   label: "matching_observations_link")
  end

  private

  def render_row(naming: @naming, user: @user, consensus: @consensus)
    render(Views::Controllers::Observations::Show::Namings::Row.new(
             naming: naming, user: user, consensus: consensus
           ))
  end

  # Wire up an Occurrence linking @obs to a sibling observation
  # and return the sibling. The Row's "Matching Observations" link
  # reads `@naming.observation.occurrence`, so @obs needs an
  # occurrence in the multi-proposer / sibling-reasons tests.
  def wire_up_occurrence_with_sibling
    sibling = observations(:detailed_unknown_obs)
    occ = ::Occurrence.create!(user: @user, primary_observation: @obs)
    @obs.update!(occurrence: occ)
    sibling.update!(occurrence: occ)
    sibling
  end

  # Create a naming on `obs` (focal or sibling), optionally with a
  # used reason so it surfaces in `grouped_reasons`.
  def create_naming_on(obs, user:, used_reason: nil)
    naming = ::Naming.create!(observation: obs,
                              name: names(:agaricus_campestris),
                              user: user)
    if used_reason
      naming.update_reasons(1 => used_reason)
      naming.save!
    end
    naming
  end
end
