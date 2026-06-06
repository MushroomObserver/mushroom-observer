# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Observations::Show::Namings
  class RowTest < ComponentTestCase
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
      # Selector class flows through from `Components::UserLink`:
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

    private

    def render_row(naming: @naming, user: @user, consensus: @consensus)
      render(Row.new(naming: naming, user: user, consensus: consensus))
    end
  end
end
