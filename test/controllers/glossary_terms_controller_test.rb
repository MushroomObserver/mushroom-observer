# frozen_string_literal: true

require "test_helper"

class GlossaryTermsControllerTest < FunctionalTestCase
  # ***** show *****
  def test_show
    glossary_term = glossary_terms(:plane_glossary_term)
    get(:show, id: glossary_term.id)
    assert_response :success
    assert_template("show")
    assert_select("body", /#{glossary_term.description}/,
                  "Page is missing glossary term description")
  end

  def test_show_past_term
    get(:show_past_glossary_term, id: conic.id, version: conic.version - 1)
    assert_template(:show_past_glossary_term, partial: "_glossary_term")
  end

  def test_show_past_term_no_version
    get(:show_past_glossary_term, id: conic.id)
    assert_response(:redirect)
  end

  def test_show_past_term_prior_version_link
    prior_version_target = "/glossary_terms/show_past_glossary_term/" \
                           "#{square.id}?version=#{square.version - 1}"
    get(:show, id: square.id)
    assert_select "a[href='#{prior_version_target}']"
  end

  # ***** index *****
  def test_index
    get(:index)
    assert_template(:index)
    GlossaryTerm.find_each do |term|
      assert_select("a[href*='#{glossary_term_path(term.id)}']", true,
                    "Index should link to each Glossary Term, including " \
                    "#{term.name} (##{term.id})")
    end
  end

  # ***** create *****
  def test_new_no_login
    get(:new)
    assert_response(:redirect)
  end

  def test_new_logged_in
    login
    get(:new)
    assert_template(:new)
  end

  def test_create
    user = login
    params = create_glossary_term_params
    post(:create, params)
    glossary_term = GlossaryTerm.order(created_at: :desc).first

    assert_equal(params[:glossary_term][:name], glossary_term.name)
    assert_equal(params[:glossary_term][:description],
                 glossary_term.description)
    assert_not_nil(glossary_term.rss_log)
    assert_equal(user.id, glossary_term.user_id)
    assert_response(:redirect)
  end

  # ***** actions that modify existing terms: :edit, :update, :destroy *****

  def test_edit_no_login
    get(:edit, id: conic.id)
    assert_response(:redirect)
  end

  def test_edit_logged_in
    login
    get(:edit, id: conic.id)
    assert_template(:edit)
  end

  def test_update
    old_count = GlossaryTerm::Version.count
    make_admin
    params = create_glossary_term_params
    params[:id] = conic.id.to_s

    post(:update, params)
    conic.reload

    assert_equal(params[:glossary_term][:name], conic.name)
    assert_equal(params[:glossary_term][:description], conic.description)
    assert_equal(old_count + 1, GlossaryTerm::Version.count)
    assert_response(:redirect)
  end

  def test_destroy
    term = GlossaryTerm.first
    params  = { id: term.id }

    login(users(:zero_user).login)
    get(:destroy, params)
    assert(GlossaryTerm.exists?(term.id),
          "Non-admin should not be able to destroy glossary term")
    assert_flash_text(:permission_denied.l)
    assert_response(:redirect)

    login(term.user.login)
    make_admin
    get(:destroy, params)
    assert_not(GlossaryTerm.exists?(term.id),
               "Admin failed to destroy GlossaryTerm")
    assert_flash_success
    assert_response(:redirect)
  end

  def test_destroy_links_presence
    term = GlossaryTerm.first
    login(users(:zero_user).login)

    get(:show, id: term.id)
    assert_select(
      "a", { text: :destroy_glossary_term.t, count: 0 },
      "Non-admin should not have link to #{:destroy_glossary_term.t}"
    )

    make_admin
    get(:show, id: term.id)
    assert_select(
      "a", { text: :destroy_glossary_term.t, count: 1 },
      "Admin should have link to #{:destroy_glossary_term.t}"
    )
  end

  ##############################################################################

  private

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
end
