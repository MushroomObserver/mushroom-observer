# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Observations::Namings::Votes
  class FormTest < ComponentTestCase
    def setup
      super
      @naming = namings(:minimal_unknown_naming)
      # The form picks the opinion-vs-confidence menu based on
      # whether `user` owns the naming (or is admin). Default the
      # test viewer to the naming's proposer so the confidence-menu
      # branch is reachable without further setup; tests that need
      # a non-proposer viewer override `user:` in `render_form`.
      @user = @naming.user
    end

    # ---- form-tag attributes --------------------------------------------

    def test_form_has_correct_id_and_classes
      # The form id pins to the naming so multiple naming rows on the
      # same page can each have their own form. Classes carry the
      # Bootstrap positioning the legacy helper used.
      html = render_form

      assert_html(html, "form#naming_vote_form_#{@naming.id}")
      assert_html(html, "form.naming-vote-form")
      assert_html(html, "form.d-inline-block")
    end

    def test_form_wires_stimulus_and_turbo
      html = render_form

      # Stimulus root + Turbo on so the controller can intercept
      # change events and submit via turbo without a full page nav.
      assert_html(html, "form[data-controller='naming-vote']")
      assert_html(html, "form[data-turbo='true']")
      # `naming_id` and `localization` (JSON-encoded) are read by
      # the JS to talk back to the correct row and pick localized
      # confirm-dialog text.
      assert_html(html, "form[data-naming-id='#{@naming.id}']")
      assert_html(html, "form[data-localization]")
    end

    def test_new_vote_posts_to_namings_votes_collection
      html = render_form(vote: nil)

      # No existing vote → POST to the votes collection path.
      expected = routes.observation_naming_votes_path(
        observation_id: @naming.observation_id, naming_id: @naming.id
      )
      assert_html(html, "form[action='#{expected}']")
      # Superform omits the hidden `_method` field for POST.
      assert_no_html(html, "input[name='_method'][value='patch']")
    end

    def test_existing_vote_patches_to_vote_resource
      vote = persisted_vote(@naming, users(:rolf), 1.0)
      html = render_form(vote: vote)

      expected = routes.observation_naming_vote_path(
        observation_id: @naming.observation_id,
        naming_id: @naming.id, id: vote.id
      )
      assert_html(html, "form[action='#{expected}']")
      # Superform emits a hidden `_method=patch` for non-POST verbs.
      assert_html(html, "input[name='_method'][value='patch']")
    end

    # ---- vote select ----------------------------------------------------

    def test_select_carries_stimulus_target_and_action
      html = render_form

      # Stimulus target/action wires the change event to the JS that
      # auto-submits the form when the user picks a value.
      assert_html(html, "select[name='vote[value]']")
      assert_html(html, "select#vote_value_#{@naming.id}")
      assert_html(html, "select[data-naming-vote-target='select']")
      assert_html(html, "select[data-action='naming-vote#sendVote']")
    end

    def test_opinion_menu_when_no_vote
      html = render_form(vote: nil)

      # Fresh voter (no existing vote) → opinion menu, which carries
      # the extra "No Opinion" sentinel at the top.
      assert_html(html, "select option[value='0']",
                  text: :vote_no_opinion.l)
    end

    def test_opinion_menu_when_vote_is_zero
      vote = ::Vote.new(naming: @naming, value: 0.0)
      html = render_form(vote: vote)

      # `value: 0` is the "No Opinion" sentinel — still on the
      # opinion menu, not the confidence menu.
      assert_html(html, "select option[value='0']",
                  text: :vote_no_opinion.l)
    end

    def test_confidence_menu_when_user_has_real_vote
      vote = ::Vote.new(naming: @naming, value: 2.0)
      html = render_form(vote: vote)

      # Real (non-zero) existing vote → narrower confidence menu;
      # the "No Opinion" sentinel is absent.
      assert_no_html(html, "select option[value='0']")
      assert_html(html, "select option[value='2.0'][selected]")
    end

    def test_opinion_menu_when_viewer_is_not_proposer
      # Viewer doesn't own the naming → opinion menu, even when
      # they have a non-zero existing vote, since they haven't
      # "earned" the confidence-menu shortcut.
      other_user = users(:dick) # not the proposer
      html = render_form(user: other_user,
                         vote: ::Vote.new(naming: @naming, value: 2.0))

      assert_html(html, "select option[value='0']",
                  text: :vote_no_opinion.l)
    end

    def test_opinion_menu_when_no_user
      # Anonymous viewer (no `user:`) → opinion menu always.
      html = render_form(user: nil,
                         vote: ::Vote.new(naming: @naming, value: 2.0))

      assert_html(html, "select option[value='0']",
                  text: :vote_no_opinion.l)
    end

    # ---- context hidden field + noscript fallback ----------------------

    def test_renders_context_hidden_field
      html = render_form(context: "namings_table")

      # Submitted alongside the vote so the controller can pick the
      # right Turbo Stream response shape for whichever surface
      # this form is on.
      assert_html(html, "input[type='hidden'][name='context']" \
                        "[value='namings_table']")
    end

    def test_noscript_submit_carries_stimulus_target
      html = render_form

      # The noscript-wrapped submit is the JS-disabled fallback. The
      # Stimulus target lets the JS hide it once it takes over.
      assert_includes(html, "<noscript>")
      assert_html(html,
                  "noscript button[type='submit']" \
                  "[data-naming-vote-target='submit']")
    end

    private

    def render_form(user: @user, vote: nil, context: "namings_table")
      render(Form.new(naming: @naming, user: user,
                      vote: vote, context: context))
    end

    # Build a saved Vote so `vote.persisted?` is true (Superform reads
    # it to decide PATCH vs POST). Using `find_or_create_by` keeps the
    # fixture surface tiny and lets multiple tests share the row.
    def persisted_vote(naming, user, value)
      ::Vote.find_or_create_by(naming: naming, user: user) do |v|
        v.value = value
        v.observation = naming.observation
      end
    end
  end
end
