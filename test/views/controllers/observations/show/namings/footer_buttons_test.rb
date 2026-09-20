# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::Namings::FooterButtonsTest <
  ComponentTestCase
  def setup
    super
    @obs = observations(:coprinus_comatus_obs)
    @user = users(:rolf)
  end

  def test_layout_pins_buttons_on_left_consensus_help_on_right
    html = render_footer_buttons

    # Buttons column is 4 of 12 at md+; the consensus-help blurb
    # takes the remaining 8. Both full-width (stacked) below md,
    # since the buttons column is empty there. Both inside the
    # leftmost col-sm-11 so the right gutter aligns with the
    # eyes-column above.
    assert_html(html, ".col-sm-11 > .row > .col-12.col-md-4")
    assert_html(html, ".col-sm-11 > .row > .col-12.col-md-8")
  end

  def test_renders_propose_naming_modal_link_without_icon
    # The "Propose new name" button is text-only here (the icon
    # variant is in the Header). ModalLink delegates to
    # IconLink only when `icon:` is present in opts; with the
    # icon stripped, ModalLink renders a plain `<a>` with the
    # tab title as its content.
    html = render_footer_buttons

    assert_html(html, "a[data-modal='modal_obs_#{@obs.id}_naming']")
    assert_no_html(html, "a[data-modal='modal_obs_#{@obs.id}_naming'] " \
                        "svg.mo-icon-add")
  end

  def test_propose_button_is_modal_trigger_link
    html = render_footer_buttons

    assert_html(html, "a.propose-naming-link" \
                      "[data-controller='modal-toggle']" \
                      "[data-modal='modal_obs_#{@obs.id}_naming']")
  end

  def test_renders_consensus_help_blurb
    html = render_footer_buttons

    # `.as_displayed` (`app/extensions/string.rb`) strips HTML tags
    # and unescapes entities — gives us what the user reads, which
    # is what `assert_html(text:)` compares against (it extracts
    # text content, not raw markup).
    assert_html(html, "#namings_consensus_help",
                text: :show_namings_consensus_help.t.as_displayed)
  end

  def test_consensus_help_collapsed_by_default_visible_at_sm_up
    html = render_footer_buttons

    # `.collapse` with no `.show` -- collapsed below `sm`; `d-sm-block`
    # forces it visible at `sm`+ regardless (see footer_buttons.rb).
    assert_html(html, "#namings_consensus_help.collapse.d-sm-block")
    assert_no_html(html, "#namings_consensus_help.show")
  end

  def test_mobile_help_toggle_targets_consensus_help
    html = render_footer_buttons

    assert_html(html,
                "a.d-sm-none[data-toggle='collapse']" \
                "[href='#namings_consensus_help']" \
                "[aria-controls='namings_consensus_help']")
  end

  # ---- suggest-names button gating ----------------------------------

  def test_suggest_button_hidden_for_non_admin_non_beta_user
    # Default `rolf` is not admin and not in the
    # `image_model_beta_testers` list → button absent.
    html = render_footer_buttons

    assert_no_html(html, "button[data-controller='suggestions']")
  end

  def test_suggest_button_visible_for_admin
    admin = users(:rolf)
    admin.stub(:admin, true) do
      html = render_footer_buttons(user: admin)

      assert_html(html, "button[data-controller='suggestions']")
      assert_html(html,
                  "button[data-action='suggestions#suggestTaxa']")
    end
  end

  def test_suggest_button_hidden_when_obs_has_no_thumb_image
    # Even an admin doesn't see the button without a thumb image
    # to seed the classifier.
    admin = users(:rolf)
    @obs.thumb_image_id = nil
    admin.stub(:admin, true) do
      html = render_footer_buttons(user: admin)

      assert_no_html(html, "button[data-controller='suggestions']")
    end
  end

  private

  def render_footer_buttons(user: @user, obs: @obs)
    render(Views::Controllers::Observations::Show::Namings::FooterButtons.new(
             user: user, obs: obs
           ))
  end
end
