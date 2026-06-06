# frozen_string_literal: true

require("test_helper")

class CollectionNumbersHelperTest < ActionView::TestCase
  include CollectionNumbersHelper
  include LinkHelper

  def test_remove_collection_number_button
    c_n = collection_numbers(:minimal_unknown_coll_num)
    obs = observations(:minimal_unknown_obs)

    html = remove_collection_number_button(c_n, obs)
    doc = Nokogiri::HTML(html)

    expected_path = collection_number_path(c_n.id, observation_id: obs.id)
    assert(doc.at_css("form[action='#{expected_path}']"),
           "Expected form targeting the collection number removal path")
    assert(doc.at_css(".remove_collection_number_link_#{c_n.id}"),
           "Expected element with the per-record CSS class")
  end
end
