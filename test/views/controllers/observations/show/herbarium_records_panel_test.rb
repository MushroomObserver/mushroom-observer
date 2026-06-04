# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::HerbariumRecordsPanelTest <
  ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
  end

  def test_renders_section_id
    html = render(panel_with(@obs))

    assert_html(html, "#observation_herbarium_records")
  end

  def test_empty_with_sibling_records_uses_plural_label
    obs = ::Observation.where.missing(:herbarium_records).
          first
    skip("Need an obs fixture without herbarium_records") unless obs

    html = render(
      Views::Controllers::Observations::Show::HerbariumRecordsPanel.new(
        obs: obs, user: obs.user, has_sibling_records: true
      )
    )

    assert_includes(html, "#{:Herbarium_records.t}:")
    assert_no_html(html, "li")
  end

  def test_readonly_list_when_viewer_cannot_add
    record = ::HerbariumRecord.joins(:observations).
             where.not(herbarium_id: nil).distinct.first ||
             skip("Need a herbarium_record attached to an obs")
    obs = record.observations.first
    stranger = users(:lone_wolf)
    skip("lone_wolf curates herbaria") if stranger.curated_herbaria.any?

    html = render(
      Views::Controllers::Observations::Show::HerbariumRecordsPanel.new(
        obs: obs, user: stranger, has_sibling_records: false
      )
    )

    assert_no_html(html, "a[data-modal*='herbarium_record']")
  end

  private

  def panel_with(obs, user = @user)
    Views::Controllers::Observations::Show::HerbariumRecordsPanel.new(
      obs: obs, user: user, has_sibling_records: false
    )
  end
end
