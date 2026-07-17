# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::CollectionNumbersSectionTest <
  ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
  end

  def test_renders_section_id
    html = render(panel_with(@obs))

    assert_html(html, "#observation_collection_numbers")
  end

  # Empty + can-edit path with siblings carrying records: the
  # header label switches from "no collection numbers" prose to
  # the plural-title label so users notice the cross-occurrence
  # records exist.
  def test_empty_with_sibling_records_uses_plural_label
    obs = ::Observation.where.missing(:collection_numbers).
          first
    skip("Need an obs fixture without collection_numbers") unless obs

    html = render(
      Views::Controllers::Observations::Show::CollectionNumbersSection.new(
        obs: obs, user: obs.user, has_sibling_records: true
      )
    )

    assert_includes(html, "#{:Collection_numbers.t}:")
    assert_no_html(html, "li")
  end

  # Read-only one-liner: obs has collection numbers but the
  # viewer doesn't have edit permission.
  def test_readonly_list_when_viewer_cannot_edit
    cn = collection_numbers(:detailed_unknown_coll_num_one)
    obs = cn.observations.first
    stranger = users(:lone_wolf)

    html = render(
      Views::Controllers::Observations::Show::CollectionNumbersSection.new(
        obs: obs, user: stranger, has_sibling_records: false
      )
    )

    # No `<ul class="tight-list">` editable list, no edit-modal
    # links — readonly path just renders the show-link.
    assert_no_html(html, "ul.tight-list")
    assert_no_html(html, "a[data-modal*='collection_number']")
  end

  private

  def panel_with(obs, user = @user)
    Views::Controllers::Observations::Show::CollectionNumbersSection.new(
      obs: obs, user: user, has_sibling_records: false
    )
  end
end
