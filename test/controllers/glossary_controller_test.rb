require "test_helper"

# tests of GlossaryController
class GlossaryControllerTest < FunctionalTestCase
  def test_show_glossary_term
    glossary_term = glossary_terms(:plane_glossary_term)
    get_with_dump(:show_glossary_term, id: glossary_term.id)
    assert_template("show_glossary_term")
  end

  def test_show_past_glossary_term
    conic = glossary_terms(:conic_glossary_term)
    get_with_dump(:show_past_glossary_term, id: conic.id,
                  version: conic.version - 1)
    assert_template("show_past_glossary_term", partial: "_glossary_term")
  end

  def test_show_past_glossary_term_no_version
    conic = glossary_terms(:conic_glossary_term)
    get_with_dump(:show_past_glossary_term, id: conic.id)
    assert_response(:redirect)
  end

  def test_index
    get_with_dump(:index)
    assert_template("index")
  end

  def test_create_glossary_term
    get(:create_glossary_term)
    assert_response(:redirect)

    login
    get_with_dump(:create_glossary_term)
    assert_template("create_glossary_term")
  end

  def create_glossary_term_params
    return {
      glossary_term: { name: "Convex", description: "Boring old convex" },
      copyright_holder: "Insil Choi",
      date: { copyright_year: "2013" },
      upload: { license_id: "1" }
    }
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

  def test_edit_glossary_term
    conic = glossary_terms(:conic_glossary_term)
    get_with_dump(:edit_glossary_term, id: conic.id)
    assert_response(:redirect)

    login
    get_with_dump(:edit_glossary_term, id: conic.id)
    assert_template("edit_glossary_term")
  end

  def test_edit_glossary_term_post
    conic = glossary_terms(:conic_glossary_term)
    count = GlossaryTerm::Version.count
    make_admin

    params = create_glossary_term_params
    params[:id] = conic.id
    post(:edit_glossary_term, params)
    conic.reload

    assert_equal(params[:glossary_term][:name], conic.name)
    assert_equal(params[:glossary_term][:description], conic.description)
    assert_equal(count+1, GlossaryTerm::Version.count)
    assert_response(:redirect)
  end

  def test_generate_and_show_past_glossary_term
    login
    glossary_term = glossary_terms(:plane_glossary_term)
    old_count = glossary_term.versions.length
    glossary_term.update(description: "Are we flying yet?")
    glossary_term.reload
    new_count = glossary_term.versions.length
    assert_equal(1, new_count - old_count)
    get_with_dump(:show_past_glossary_term, id: glossary_term.id,
                  version: glossary_term.version - 1)
    assert_template("show_past_glossary_term", partial: "_glossary_term")
  end
end
