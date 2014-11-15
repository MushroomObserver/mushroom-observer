require "test_helper"

# functional tests of glossary controller and views
class GlossaryControllerTest < FunctionalTestCase
  # ***** show *****
  def test_show_glossary_term
    glossary_term = glossary_terms(:plane_glossary_term)
    get_with_dump(:show_glossary_term, id: glossary_term.id)
    assert_template(action: "show_glossary_term")
  end

  def test_show_past_glossary_term_no_version
    conic = glossary_terms(:conic_glossary_term)
    get_with_dump(:show_past_glossary_term, id: conic.id)
    assert_response(:redirect)
  end

  def test_show_past_glossary_term_with_version
    conic = glossary_terms(:conic_glossary_term)
    get_with_dump(:show_past_glossary_term,
                  id: conic.id, version: conic.version - 1)
    assert_template(action: "show_past_glossary_term",
                    partial: "_glossary_term")
  end

  test "show past glossary term prior version link target" do
    square = glossary_terms(:square_glossary_term)
    prior_version_target = "/glossary/show_past_glossary_term/" \
                          "#{square.id}?version=#{square.version - 1}"
    get(:show_glossary_term, id: square.id)
    assert_select "a[href=?]", prior_version_target
  end

  # ***** index *****
  def test_index
    get_with_dump(:index)
    assert_template(action: "index")
  end

  # ***** create *****
  def convex_params
    { glossary_term:
      { name: "Convex", description: "Boring" },
      copyright_holder: "Me",
      date: { copyright_year: 2013 }, upload: { license_id: 1 }
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

  def test_create_glossary_term_not_logged_in
    get(:create_glossary_term)
    assert_response(:redirect)
  end

  def test_create_glossary_term_logged_in
    login
    get_with_dump(:create_glossary_term)
    assert_template(action: "create_glossary_term")
  end

  def test_create_glossary_term_name
    assert_equal(convex_params[:glossary_term][:name], posted_term.name)
  end

  def test_create_glossary_term_description
    assert_equal(convex_params[:glossary_term][:description],
                 posted_term.description)
  end

  def test_create_glossary_term_rss_log
    assert_not_nil(posted_term.rss_log)
  end

  def test_create_glossary_term_user_id
    user = login
    assert_equal(user.id, posted_term.user_id)
  end

  def test_create_glossary_term_redirect
    login_and_post_convex
    assert_response(:redirect)
  end

  # ***** edit *****
  def test_edit_glossary_term
    conic = glossary_terms(:conic_glossary_term)
    get_with_dump(:edit_glossary_term, id: conic.id)
    assert_response(:redirect)

    login
    get_with_dump(:edit_glossary_term, id: conic.id)
    assert_template(action: "edit_glossary_term")
  end

  def test_edit_glossary_term_post
    conic = glossary_terms(:conic_glossary_term)
    old_count = GlossaryTerm::Version.count
    make_admin

    params = { id: conic.id,
               glossary_term:
               { name: "Convex", description: "Boring old convex" },
               copyright_holder: "Insil Choi", date: { copyright_year: 2013 },
               upload: { license_id: 1 }
             }

    post(:edit_glossary_term, params)
    # see if conic changed
    conic.reload
    assert_equal(params[:glossary_term][:name], conic.name)
    assert_equal(params[:glossary_term][:description], conic.description)
    assert_equal(old_count + 1, GlossaryTerm::Version.count)
    assert_response(:redirect)
  end

  def test_generate_and_show_past_glossary_term
    login
    glossary_term = glossary_terms(:plane_glossary_term)
    old_length = glossary_term.versions.length
    glossary_term.update_attributes(description: "Are we flying yet?")
    glossary_term.reload
    assert_equal(old_length + 1, glossary_term.versions.length)
    get_with_dump(:show_past_glossary_term,
                  id: glossary_term.id,
                  version: glossary_term.version - 1)
    assert_template(action: "show_past_glossary_term",
                    partial: "_glossary_term")
  end
end
