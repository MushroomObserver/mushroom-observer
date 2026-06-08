# frozen_string_literal: true

require("test_helper")

class LinkHelperTest < ActionView::TestCase
  include LinkHelper

  # add_q_param lives in ApplicationController::Queries (controller context
  # only). Return the path unchanged so helper tests run without a controller.
  def add_q_param(path, _query = nil)
    path
  end

  # Lines 41-44: non-block form — link = second positional (path),
  # content = first positional (text)
  def test_active_link_with_query_non_block_form
    html = active_link_with_query("Home", "/")

    assert_includes(html, 'href="/"',
                    "Expected href from path argument")
    assert_includes(html, "Home",
                    "Expected text from first positional argument")
  end

  # Lines 41-44: block form — link = first positional (path),
  # content from block
  def test_active_link_with_query_block_form
    html = active_link_with_query("/") { "Block content" }

    assert_includes(html, 'href="/"',
                    "Expected href from first positional arg in block form")
    assert_includes(html, "Block content",
                    "Expected content rendered from block")
  end

  # Line 117: external_link uses concat — capture wraps the output buffer
  def test_external_link_renders_link
    link = external_links(:coprinus_comatus_obs_mycoportal_link)

    html = capture { external_link(link) }

    assert_includes(html, link.url,
                    "Expected the external site URL in the rendered link")
  end

  # Line 218: download_button renders a GET link to new_download_species_list
  def test_download_button_renders_link_to_download_path
    sl = species_lists(:first_species_list)

    html = download_button(target: sl)
    doc = Nokogiri::HTML(html)

    expected_path = new_download_species_list_path(id: sl.id)
    assert(doc.at_css("a[href='#{expected_path}']"),
           "Expected link to the species list download path")
  end
end
