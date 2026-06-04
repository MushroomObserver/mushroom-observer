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

  private

  def panel_with(obs, user = @user)
    Views::Controllers::Observations::Show::HerbariumRecordsPanel.new(
      obs: obs, user: user, has_sibling_records: false
    )
  end
end
