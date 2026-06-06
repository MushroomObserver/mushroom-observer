# frozen_string_literal: true

require("test_helper")

class HerbariumRecordsHelperTest < ActionView::TestCase
  include HerbariumRecordsHelper
  include LinkHelper

  def test_remove_herbarium_record_button
    h_r = herbarium_records(:interesting_unknown)
    obs = observations(:minimal_unknown_obs)

    html = remove_herbarium_record_button(h_r, obs)
    doc = Nokogiri::HTML(html)

    expected_path = herbarium_record_path(h_r.id, observation_id: obs.id)
    assert(doc.at_css("form[action='#{expected_path}']"),
           "Expected form targeting the herbarium record removal path")
    assert(doc.at_css(".remove_herbarium_record_link_#{h_r.id}"),
           "Expected element with the per-record CSS class")
  end
end
