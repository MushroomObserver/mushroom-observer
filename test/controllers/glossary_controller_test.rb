require "test_helper"

# functional tests of glossary controller and views
# tests of controller methods which do not change glossary terms
class GlossaryControllerTest < FunctionalTestCase
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

# tests of controller methods which do not change glossary terms
class GlossaryControllerShowAndIndexTest < GlossaryControllerTest
  def setup
    @controller = GlossaryController.new
    super
  end

  # ***** show *****
  def test_show_glossary_term
    glossary_term = glossary_terms(:plane_glossary_term)
    get_with_dump(:show_glossary_term, id: glossary_term.id)
    assert_template("show_glossary_term")
  end

  def test_show_past_glossary_term
    get_with_dump(:show_past_glossary_term, id: conic.id,
                                            version: conic.version - 1)
    assert_template(:show_past_glossary_term, partial: "_glossary_term")
  end

  def test_show_past_glossary_term_no_version
    skip "Skip until we can figure out why `redirect_to` throws an Error."
    get_with_dump(:show_past_glossary_term, id: conic.id)
    assert_response(:redirect)
  end

  def test_show_past_glossary_term_prior_version_link_target
    prior_version_target = "/glossary/show_past_glossary_term/" \
                          "#{square.id}?version=#{square.version - 1}"
    get(:show_glossary_term, id: square.id)
    assert_select "a[href='#{prior_version_target}']"
  end

  # ***** index *****
  def test_index
    get_with_dump(:index)
    assert_template(:index)
  end
end

# tests of controller methods which create glossary terms
class GlossaryControllerCreateTest < GlossaryControllerTest
  def setup
    @controller = GlossaryController.new
  end

  # ***** create *****
  def convex_params
    {
      glossary_term:
      { name: "Convex", description: "Boring" },
      copyright_holder: "Me",
      date: { copyright_year: 2013 },
      upload: { license_id: licenses(:ccnc25).id }
    }
  end

  def posted_term
    login_and_post_convex
    GlossaryTerm.find(:all, order: "created_at DESC")[0]
  end

  def login_and_post_convex
    login
    post(:create_glossary_term, convex_params)
  end

  def test_create_glossary_term_no_login
    get(:create_glossary_term)
    assert_response(:redirect)
  end

  def test_create_glossary_term_logged_in
    login
    get_with_dump(:create_glossary_term)
    assert_template(:create_glossary_term)
  end

  def test_create_glossary_term_post
    user = login
    params = create_glossary_term_params
    post(:create_glossary_term, params)
    glossary_term = GlossaryTerm.order(created_at: :desc).first

    assert_equal(params[:glossary_term][:name], glossary_term.name)
    assert_equal(params[:glossary_term][:description],
                 glossary_term.description)
    assert_not_nil(glossary_term.rss_log)
    assert_equal(user.id, glossary_term.user_id)
    assert_response(:redirect)
  end
end

# tests of controller methods which edit glossary terms
class GlossaryControllerEditTest < GlossaryControllerTest
  # ##### helpers #####
  def setup
    @controller = GlossaryController.new
  end

  def conic
    glossary_terms(:conic_glossary_term)
  end

  def changes_to_conic
    {
      id: conic.id,
      glossary_term: { name: "Convex", description: "Boring old convex" },
      copyright_holder: "Insil Choi", date: { copyright_year: 2013 },
      upload: { license_id: licenses(:ccnc25).id }
    }
  end

  def post_conic_edit_changes
    make_admin
    post(:edit_glossary_term, changes_to_conic)
  end

  def post_conic_edit_changes_and_reload
    post_conic_edit_changes
    conic.reload
  end

  ##### tests #####
  def test_edit_glossary_term_no_login
    get_with_dump(:edit_glossary_term, id: conic.id)
    assert_response(:redirect)
  end

  def test_edit_glossary_term_logged_in
    login
    get_with_dump(:edit_glossary_term, id: conic.id)
    assert_template(:edit_glossary_term)
  end

  def test_edit_glossary_term_post
    old_count = GlossaryTerm::Version.count
    make_admin
    params = create_glossary_term_params
    params[:id] = conic.id

    post(:edit_glossary_term, params)
    conic.reload

    assert_equal(params[:glossary_term][:name], conic.name)
    assert_equal(params[:glossary_term][:description], conic.description)
    assert_equal(old_count + 1, GlossaryTerm::Version.count)
    assert_response(:redirect)
  end

  def update_and_reload_plane_past_version
    login
    glossary_term = glossary_terms(:plane_glossary_term)
    old_count = glossary_term.versions.length

    glossary_term.update(description: "Are we flying yet?")
    glossary_term.reload

    assert_equal(old_count + 1, glossary_term.versions.length)

    get_with_dump(:show_past_glossary_term, id: glossary_term.id,
                                            version: glossary_term.version - 1)
    assert_template(:show_past_glossary_term, partial: "_glossary_term")
  end
end
