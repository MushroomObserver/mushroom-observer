# frozen_string_literal: true

require("test_helper")

# functional tests of glossary controller and views
class GlossaryTermsControllerTest < FunctionalTestCase
  # ***** helpers *****
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

# ---------- Actions to Display data (index, show, etc.) -----------------------
class GlossaryControllerShowAndIndexTest < GlossaryTermsControllerTest
  def setup
    @controller = GlossaryTermsController.new
    super
  end

  # ***** index *****
  def test_index
    get(:index)
    assert_template(:index)
  end

  # ***** show *****
  def test_show
    glossary_term = glossary_terms(:plane_glossary_term)
    get(:show, id: glossary_term.id)
    assert_template("show")
  end

  def test_show_past_term
    get(:show_past_glossary_term, id: conic.id,
                                  version: conic.version - 1)
    assert_template(:show_past_glossary_term, partial: "_glossary_term")
  end

  def test_show_past_term_no_version
    get(:show_past_glossary_term, id: conic.id)
    assert_response(:redirect)
  end

  def test_show_past_term_prior_version_link_target
    prior_version_path =
      "/glossary_terms/#{square.id}/show_past_glossary_term?" \
      "version=#{square.version - 1}"
    get(:show, id: square.id)

    assert_select("a[href='#{prior_version_path}']")
  end
end

# tests of controller methods which create glossary terms
class GlossaryControllerCreateTest < GlossaryTermsControllerTest
  def setup
    @controller = GlossaryTermsController.new
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
    get(:create_glossary_term)
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
class GlossaryControllerEditTest < GlossaryTermsControllerTest
  # ##### helpers #####
  def setup
    @controller = GlossaryTermsController.new
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
    get(:edit_glossary_term, id: conic.id)
    assert_response(:redirect)
  end

  def test_edit_glossary_term_logged_in
    login
    get(:edit_glossary_term, id: conic.id)
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

    get(:show_past_glossary_term, id: glossary_term.id,
                                  version: glossary_term.version - 1)
    assert_template(:show_past_glossary_term, partial: "_glossary_term")
  end
end

# tests of image handling
class GlossaryControllerImageTest < GlossaryTermsControllerTest
  def setup
    @controller = GlossaryTermsController.new
  end

  def term_with_image_params
    setup_image_dirs
    file = "#{::Rails.root}/test/images/Coprinus_comatus.jpg"
    file = Rack::Test::UploadedFile.new(file, "image/jpeg")

    {
      glossary_term:  { name: "Pancake", description: "Flat" },
      copyright_holder: "Me",
      date: { copyright_year: 2013 },
      upload: { license_id: licenses(:ccnc25).id },
      image: {
        "0" => {
          image: file,
          copyright_holder: "zuul",
          when: Time.current
        }
      }
    }
  end

  def test_process_image_failure
    login("rolf")
    # Simulate process_image failure.
    Image.any_instance.stubs(:process_image).returns(false)
    post(:create_glossary_term, term_with_image_params)
    assert_flash_error
  end

  def test_image_save_failure
    login("rolf")
    # Simulate image.save failure.
    Image.any_instance.stubs(:save).returns(false)
    post(:create_glossary_term, term_with_image_params)
    assert_empty(GlossaryTerm.last.images)
  end
end
