# frozen_string_literal: true

require("test_helper")

# functional tests of glossary controller and views
class GlossaryTermsControllerTest < FunctionalTestCase
  # ---------- Test actions that Display data (index, show, etc.) --------------

  # ***** index *****
  def test_index
    get(:index)
    assert_template(:index)
    GlossaryTerm.find_each do |term|
      assert_select(
        "a[href *= '#{glossary_term_path(term.id)}']", true,
        "Glossary Index missing link to #{term.unique_text_name})"
      )
    end
  end

  # ***** show *****
  def test_show
    term = glossary_terms(:square_glossary_term)
    prior_version_path =
      "/glossary_terms/#{term.id}/show_past_glossary_term?" \
      "version=#{term.version - 1}"
    get(:show, id: term.id)

    assert_template("show")
    assert_select("body", /#{term.description}/,
                  "Page is missing glossary term description")
    assert_select("a[href='#{prior_version_path}']", true,
                  "Page should have link to prior version")
  end

  # ---------- Test actions that Display forms -- (new, edit, etc.) ------------

  # ***** new *****
  def test_new # happy path
    login
    get(:new)
    assert_response(:success)
    assert_template(:new)
    assert_select("form input[name='glossary_term[name]']", { count: 1 },
                  "Form is missing field for name")
  end

  def test_new_no_login
    get(:new)
    assert_response(:redirect,
                    "Unlogged-in user should not be able to create term")
  end

  # ***** edit *****
  def test_edit  # happy path
    login
    term = GlossaryTerm.first
    get(:edit, id: term.id)
    assert_template(:edit)
    assert_response(:success)
    assert_select("form input[name='glossary_term[name]']", { count: 1 },
                  "Form is missing field for name") do
      assert_select("input[value='#{term.name}']", { count: 1 },
                    "Name should default to glossary term name")
    end
    assert_select("input#upload_image", false,
                  "edit GlossaryTerm form should omit image input form")
  end

  def test_edit_no_login
    get(:edit, id: GlossaryTerm.first.id)
    assert_response(:redirect,
                    "Unlogged-in user should not be able to edit term")
  end

  # ---------- Test actions that Modify data: (create, update, destroy, etc.) --

  # ***** create *****
  def test_create
    user = login
    params = create_term_params
    post(:create, params)
    term = GlossaryTerm.order(created_at: :desc).first

    assert_equal(params[:glossary_term][:name], term.name)
    assert_equal(params[:glossary_term][:description], term.description)
    assert_not_nil(term.rss_log)
    assert_equal(user.id, term.user_id)
    assert_response(:redirect)
  end

  def test_create_image_save_failure
    login
    # Simulate image.save failure.
    Image.any_instance.stubs(:save).returns(false)
    post(:create, term_with_image_params)
    assert_empty(GlossaryTerm.last.images)
  end

  def test_create_process_image_failure
    login
    # Simulate process_image failure.
    Image.any_instance.stubs(:process_image).returns(false)
    post(:create, term_with_image_params)
    assert_flash_error
  end

  # ***** update *****
  def test_update
    term = glossary_terms(:conic_glossary_term)
    params = changes_to_conic
    old_count = term.versions.count
    login
    post(:update, params)
    term.reload

    assert_equal(params[:glossary_term][:name], term.name)
    assert_equal(params[:glossary_term][:description], term.description)
    assert_equal(old_count + 1, term.versions.count)
    assert_response(:redirect)
  end

  # ***** update *****
  def test_destroy # happy path
    term = GlossaryTerm.first
    login(term.user.login)
    make_admin
    get(:destroy, id: term.id)

    assert_flash_success
    assert_response(:redirect)
    assert_not(GlossaryTerm.exists?(term.id),
               "Admin failed to destroy GlossaryTerm")
  end

  def test_destroy_no_login
    term = GlossaryTerm.first
    login(users(:zero_user).login)
    get(:destroy, id: term.id)

    assert_flash_text(:permission_denied.l)
    assert_response(:redirect)
    assert(GlossaryTerm.exists?(term.id),
           "Non-admin should not be able to destroy glossary term")
  end

  # ---------- Other actions ---------------------------------------------------

  def test_show_past_term # happy_path
    term = glossary_terms(:conic_glossary_term)
    get(:show_past_glossary_term, id: term.id, version: term.version - 1)
    assert_template(:show_past_glossary_term, partial: "_glossary_term")
  end

  def test_show_past_term_no_version
    term = glossary_terms(:conic_glossary_term)
    get(:show_past_glossary_term, id: term.id)
    assert_response(:redirect)
  end

  # ---------- helpers ---------------------------------------------------------

  def create_term_params
    {
      glossary_term: { name: "Convex", description: "Boring old convex" },
      copyright_holder: "Insil Choi",
      date: { copyright_year: "2013" },
      upload: { license_id: licenses(:ccnc30).id }
    }.freeze
  end

  def changes_to_conic
    {
      id: glossary_terms(:conic_glossary_term).id,
      glossary_term: { name: "Convex", description: "Boring old convex" },
      copyright_holder: "Insil Choi", date: { copyright_year: 2013 },
      upload: { license_id: licenses(:ccnc25).id }
    }.freeze
  end

  def term_with_image_params
    setup_image_dirs
    file = "#{::Rails.root}/test/images/Coprinus_comatus.jpg"
    file = Rack::Test::UploadedFile.new(file, "image/jpeg")

    {
      glossary_term: { name: "Pancake", description: "Flat" },
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
    }.freeze
  end
end
