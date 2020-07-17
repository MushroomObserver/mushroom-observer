require 'test_helper'

class GlossaryTermsControllerTest < ActionDispatch::IntegrationTest
  test "should get show" do
    get glossary_terms_show_url
    assert_response :success
  end

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

end
