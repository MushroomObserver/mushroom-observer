# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::Namings::HeaderTest <
  ComponentTestCase
  def setup
    super
    @obs = observations(:coprinus_comatus_obs)
  end

  def test_renders_panel_title_in_h4
    # The leftmost label-column carries the panel's actual title
    # in an h4 — on `xs` it's the only piece of the heading row
    # that's visible.
    html = render_header

    assert_html(html, "h4",
                text: :show_namings_proposed_names.t)
  end

  def test_renders_four_column_labels
    html = render_header

    # All four column-label `<small>`s are present. (The h4 in
    # the first column already covers `proposed_names`.) Use
    # `assert_includes` rather than `assert_html(text:)` because
    # the latter matches the first `<small>` and asserts its
    # text — useless when there are multiple `<small>`s.
    assert_includes(html, :show_namings_user.t)
    assert_includes(html, :show_namings_consensus.t)
    assert_includes(html, :show_namings_your_vote.t)
  end

  def test_label_columns_hidden_on_xs
    # The three non-leftmost label columns are hidden on `xs`
    # via `d-none d-sm-block` so only the panel title + the
    # propose icon show on mobile.
    html = render_header

    assert_html(html, ".col.col-sm-3.d-none.d-sm-block", count: 2)
    assert_html(html, ".col.col-sm-2.d-none.d-sm-block", count: 1)
  end

  def test_name_column_is_block_on_xs
    # First column (panel-title column) is `d-block` not
    # `d-none` — visible on `xs` so the panel always shows its
    # title.
    html = render_header

    assert_html(html, ".col.col-sm-4.d-block")
  end

  def test_rows_align_items_end_for_bottom_label_alignment
    # The inner row of label columns is `d-flex align-items-end`
    # so the one-line labels bottom-align with "Community Vote"
    # when it wraps to two lines on the `sm` breakpoint. `d-flex`
    # is load-bearing: MO's `.row` doesn't default to `display:
    # flex` the way Bootstrap's does, so the `align-items` would
    # be a no-op without it.
    html = render_header

    assert_html(html, ".row.d-flex.align-items-end", count: 2)
  end

  def test_renders_propose_naming_modal_link_in_mobile_column
    # Right-gutter column carries the propose-naming icon button
    # via ModalLink (data-modal points at the propose-naming
    # modal). `float-right d-sm-none` hides the button on `sm+`
    # — there the footer-buttons row owns the propose CTA.
    html = render_header

    assert_html(html, ".col-xs-2.col-sm-1 .float-right.d-sm-none")
    assert_html(html, "a[data-modal='modal_obs_#{@obs.id}_naming']")
    assert_html(html, "a[data-controller='modal-toggle']")
  end

  def test_propose_link_carries_action_url_to_namings_new
    html = render_header

    expected = routes.new_observation_naming_path(
      observation_id: @obs.id, context: "namings_table"
    )
    assert_html(html, "a[href='#{expected}']")
  end

  def test_propose_link_renders_with_plus_icon
    # Tab::Naming::New sets `icon: :add` in its html_options;
    # ModalLink routes through IconLink when an `icon:` is
    # present, which produces a glyphicon-plus span.
    html = render_header

    assert_html(html, "a span.glyphicon-plus")
  end

  private

  def render_header
    render(Views::Controllers::Observations::Show::Namings::Header.new(
             obs: @obs
           ))
  end
end
