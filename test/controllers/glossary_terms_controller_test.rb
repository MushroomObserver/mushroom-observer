# frozen_string_literal: true

require("test_helper")

# functional tests of glossary controller and views
class GlossaryTermsControllerTest < FunctionalTestCase
  ESSENTIAL_ATTRIBUTES = %w[name description].freeze

  # ---------- Test actions that Display data (index, show, etc.) --------------

  # ***** index *****
  def test_index
    get(:index)

    assert_response(:success)
    assert_title(:glossary_term_index_title.l)

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
    prior_version_path = show_past_glossary_term_path(
      term.id, version: term.version - 1
    )
    get(:show, params: { id: term.id })

    assert_response(:success)
    assert_title(:show_glossary_term_title.l(name: term.name))

    ESSENTIAL_ATTRIBUTES.each do |attr|
      assert_select("body", /#{term.send(attr)}/,
                    "Page is missing glossary term #{attr}")
    end
    assert_select("a[href='#{prior_version_path}']", true,
                  "Page should have link to prior version")
  end

  # ---------- Test actions that Display forms -- (new, edit, etc.) ------------

  # ***** new *****
  def test_new
    login
    get(:new)

    assert_response(:success)
    assert_title(:create_glossary_term_title.l)

    ESSENTIAL_ATTRIBUTES.each do |attr|
      assert_select("form #glossary_term_#{attr}", { count: 1 },
                    "Form is missing field for #{attr}")
    end
  end

  def test_new_no_login
    get(:new)
    assert_response(:redirect,
                    "Unlogged-in user should not be able to create term")
  end

  # ***** edit *****
  def test_edit
    login
    term = GlossaryTerm.first
    get(:edit, params: { id: term.id })

    assert_response(:success)
    assert_title(:edit_glossary_term_title.l(name: term.name))

    assert_select(
      "form #glossary_term_name[value='#{term.name}']", { count: 1 },
      "Form lacks Name field that defaults to glossary term name"
    )
    assert_select(
      "form #glossary_term_description",
      { text: /#{term.description}/, count: 1 },
      "Form lacks Description field that defaults to glossary term description"
    )
    assert_select("input#upload_image", false,
                  "Edit GlossaryTerm form should omit image input form")
  end

  def test_edit_no_login
    get(:edit, params: { id: GlossaryTerm.first.id })
    assert_response(:redirect,
                    "Unlogged-in user should not be able to edit term")
  end

  # ---------- Test actions that Modify data: (create, update, destroy, etc.) --

  # ***** create *****
  def test_create
    user = login
    params = create_term_params

    assert_no_difference("Image.count") do
      post(:create, params: params)
    end
    term = GlossaryTerm.order(created_at: :desc).first
    assert_equal(params[:glossary_term][:name], term.name)
    assert_equal(params[:glossary_term][:description], term.description)
    assert_not_nil(term.rss_log)
    assert_equal(user.id, term.user_id)
    assert_response(:redirect)
  end

  def test_create_upload_image
    login
    params = term_with_image_params

    assert_difference("Image.count") do
      post(:create, params: params)
    end
    term = GlossaryTerm.order(created_at: :desc).first
    assert_equal(Image.last, term.thumb_image)
  end

  def test_create_image_save_failure
    login
    # Simulate image.save failure.
    Image.any_instance.stubs(:save).returns(false)
    post(:create, params: term_with_image_params)

    assert_empty(GlossaryTerm.last.images)
  end

  def test_create_process_image_failure
    login
    # Simulate process_image failure.
    Image.any_instance.stubs(:process_image).returns(false)
    post(:create, params: term_with_image_params)

    assert_flash_error
  end

  # ***** update *****
  def test_update
    term = glossary_terms(:conic_glossary_term)
    params = changes_to_conic
    login

    assert_difference("term.versions.count") do
      post(:update, params: params)
    end
    assert_equal(params[:glossary_term][:name], term.reload.name)
    assert_equal(params[:glossary_term][:description], term.description)
    assert_redirected_to(glossary_term_path(term.id))
  end

  # ***** destroy *****
  def test_destroy_term_lacking_images
    term = glossary_terms(:no_images_glossary_term)

    login
    make_admin
    get(:destroy, params: { id: term.id })

    assert_flash_success
    assert_response(:redirect)
    assert_not(GlossaryTerm.exists?(term.id), "Failed to destroy GlossaryTerm")
  end

  def test_destroy_term_with_images
    term = glossary_terms(:unused_thumb_and_used_image_glossary_term)
    unused_image = term.thumb_image
    used_images = term.all_images - [unused_image]

    login
    make_admin
    get(:destroy, params: { id: term.id })

    assert_flash_success
    assert_response(:redirect)
    assert_not(GlossaryTerm.exists?(term.id), "Failed to destroy GlossaryTerm")

    assert_not(Image.exists?(unused_image.id),
               "Failed to destroy unused Image #{unused_image.id}")
    used_images.each do |image|
      assert(Image.exists?(image.id),
             "Image #{image.id} which was used elsewhere was destroyed")
    end
  end

  def test_destroy_no_login
    term = GlossaryTerm.first
    login(users(:zero_user).login)
    get(:destroy, params: { id: term.id })

    assert_flash_text(:permission_denied.l)
    assert_response(:redirect)
    assert(GlossaryTerm.exists?(term.id),
           "Non-admin should not be able to destroy glossary term")
  end

  # ---------- Other actions ---------------------------------------------------

  def test_show_past
    term = glossary_terms(:square_glossary_term)
    version = term.versions.first # oldest version
    get(:show_past, params: { id: term.id, version: version.version })

    assert_response(:success)
    assert_title(:show_past_glossary_term_title.l(num: version.version,
                                                  name: term.name))

    ESSENTIAL_ATTRIBUTES.each do |attr|
      assert_select("body", /#{version.send(attr)}/,
                    "Page is missing glossary term #{attr}")
    end
    assert_select("a[href='#{glossary_term_path(term.id)}']", true,
                  "Page should have link to last (current) version")
  end

  def test_show_past_no_version
    term = GlossaryTerm.first
    get(:show_past, params: { id: term.id })

    assert_response(:redirect)
  end

  # ---------- Routes ---------------------------------------------------

  def test_routes
    assert_generates("glossary_terms/1234/show_past",
                     { controller: "glossary_terms",
                       action: "show_past",
                       id: "1234" })

    assert_recognizes({ controller: "glossary_terms",
                        action: "show_past",
                        id: "1234" },
                      "glossary_terms/1234/show_past")
  end

  # ---------- helpers ---------------------------------------------------------

  def assert_title(title)
    assert_select("head title", { text: /#{title}/, count: 1 },
                  "Incorrect page or page title displayed")
  end

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
      glossary_term: {
        name: "Pancake",
        description: "Flat",
        upload_image: {
          image: file,
          copyright_holder: "zuul",
          when: Time.current
        }
      },
      copyright_holder: "Me",
      date: { copyright_year: 2013 },
      upload: { license_id: licenses(:ccnc25).id }
    }.freeze
  end
end
