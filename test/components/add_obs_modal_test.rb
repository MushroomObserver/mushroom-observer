# frozen_string_literal: true

require("test_helper")

class AddObsModalTest < ComponentTestCase
  def setup
    super
    @project = projects(:eol_project)
    @user = users(:katrina)
  end

  def test_modal_when_none_match
    html = render_modal(count: 0)

    assert_html(html, "##{Components::AddObsModal::MODAL_ID}.modal")
    assert_includes(html, "None of your observations match",
                    "Zero-count modal should show 'none' message")
    assert_not_includes(html, "btn-primary",
                        "Zero-count modal should omit submit button")
  end

  def test_modal_when_all_fit_in_one_batch
    html = render_modal(count: 3, batch_limit: 100)

    assert_includes(html, :add_obs_modal_all.l(count: 3).to_s)
    assert_includes(html, :add_obs_modal_add_all.l.to_s,
                    "Under-limit modal should label button 'Add All'")
    assert_includes(html, "btn-primary",
                    "Under-limit modal should render submit button")
  end

  # Covers body_text partial branch and submit_label add_next branch
  # (lines 61 and 97 in add_obs_modal.rb).
  def test_modal_when_more_than_batch_limit
    html = render_modal(count: 150, batch_limit: 100)

    assert_includes(
      html,
      :add_obs_modal_partial.l(count: 150, limit: 100).to_s,
      "Over-limit modal should show partial count + limit message"
    )
    assert_includes(html, :add_obs_modal_add_next.l(limit: 100).to_s,
                    "Over-limit modal should label button 'Add Next 100'")
  end

  private

  def render_modal(count:, batch_limit: 100)
    render(Components::AddObsModal.new(
             project: @project,
             candidate: @user,
             count: count,
             batch_limit: batch_limit
           ))
  end
end
