# frozen_string_literal: true

require "test_helper"

class GlossaryTermsControllerTest < FunctionalTestCase
  # ***** test helpers *****
  def conic
    glossary_terms(:conic_glossary_term)
  end

  def plane
    glossary_terms(:plane_glossary_term)
  end

  def square
    glossary_terms(:square_glossary_term)
  end

  def create_glossary_term_params
    {
      glossary_term: { name: "Convex", description: "Boring old convex" },
      copyright_holder: "Insil Choi",
      date: { copyright_year: "2013" },
      upload: { license_id: licenses(:ccnc30).id }
    }
  end

  # ***** show *****
  def test_show
    glossary_term = glossary_terms(:plane_glossary_term)
    get(:show, id: glossary_term.id)
    assert_response :success
    assert_template("show")
    assert_select("body", /#{glossary_term.description}/,
                  "Page is missing glossary term description")
  end

  def test_show_past_glossary_term
    get(:show_past_glossary_term, id: conic.id, version: conic.version - 1)
    assert_template(:show_past_glossary_term, partial: "_glossary_term")
  end

  def test_show_past_glossary_term_no_version
    get(:show_past_glossary_term, id: conic.id)
    assert_response(:redirect)
  end

  def test_show_past_glossary_term_prior_version_link_target
    prior_version_target = "/glossary/show_past_glossary_term/" \
                          "#{square.id}?version=#{square.version - 1}"
    get(:show, id: square.id)
    assert_select "a[href='#{prior_version_target}']"
  end

  # ***** index *****
  def test_index
    get(:index)
    assert_template(:index)
  end

=begin
  test "should get index" do
    get glossary_terms_index_url
    assert_response :success
  end

  test "should get new" do
    get glossary_terms_new_url
    assert_response :success
  end

  test "should get create" do
    get glossary_terms_create_url
    assert_response :success
  end

  test "should get edit" do
    get glossary_terms_edit_url
    assert_response :success
  end

  test "should get update" do
    get glossary_terms_update_url
    assert_response :success
  end

  test "should get destroy" do
    get glossary_terms_destroy_url
    assert_response :success
  end

  test "should get show_past_glossary_term" do
    get glossary_terms_show_past_glossary_term_url
    assert_response :success
  end
=end
end
