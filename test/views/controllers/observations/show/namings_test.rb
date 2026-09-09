# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::NamingsTest <
  ComponentTestCase
  def setup
    super
    @obs = observations(:coprinus_comatus_obs)
    @user = @obs.user
    @consensus = ::Observation::NamingConsensus.new(@obs)
    controller.instance_variable_set(:@user, @user)
  end

  def test_panel_has_correct_id_and_classes
    html = render_namings

    assert_html(html,
                "#observation_namings.card.namings-table")
  end

  def test_panel_carries_section_update_stimulus_root
    # Stimulus root + user value: the `section-update` controller
    # reads `section-update-user-value` to know whose modals to
    # close when a broadcast arrives.
    html = render_namings

    assert_html(html,
                "#observation_namings[data-controller='section-update']")
    assert_html(html, "#observation_namings" \
                      "[data-section-update-user-value='#{@user.id}']")
  end

  def test_renders_header_in_heading_slot
    # Heading is `title: false` (no `.card-title` wrapper) — the
    # header view supplies its own h4. Check that the header's
    # propose-modal anchor lives inside the card-header.
    html = render_namings

    assert_html(html, ".card-header.namings-table-header " \
                      "a[data-modal='modal_obs_#{@obs.id}_naming']")
  end

  def test_renders_rows_in_unwrapped_body
    # Body is `wrapper: false` so the list-group sits flush
    # against the card-header without the default `.card-body`
    # padding.
    html = render_namings

    assert_html(html,
                ".card > #namings_table_rows.list-group.list-group-flush")
  end

  def test_renders_footer_buttons_first_footer
    # First footer carries the propose-naming + suggest-names
    # buttons plus the consensus-help blurb.
    html = render_namings

    assert_html(html, ".card-footer .card-text.small")
    assert_html(html, ".card-footer " \
                      "a[data-modal='modal_obs_#{@obs.id}_naming']")
  end

  def test_renders_footer_legend_in_second_footer_hidden_on_xs
    # Second footer carries the eye-icon legend; the slot wraps
    # itself in `d-none d-sm-block` so it doesn't show on `xs`.
    html = render_namings

    assert_html(html, ".card-footer.d-none.d-sm-block .vote-icon-yours")
    assert_html(html, ".card-footer.d-none.d-sm-block .vote-icon-consensus")
  end

  private

  def render_namings
    render(Views::Controllers::Observations::Show::Namings.new(
             obs: @obs, user: @user, consensus: @consensus
           ))
  end
end
