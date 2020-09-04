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
      assert_select("form [name='glossary_term[#{attr}]']", { count: 1 },
                    "Form should have one field for #{attr}")
    end
    assert_select("input#glossary_term_upload_image", { count: 1 },
                  "Form should include upload image field")
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
      "form [name='glossary_term[name]']", { count: 1 },
      "Form should have one field for Name"
    ) do
      assert_select(
        "[value='#{term.name}']", true,
        "Name field should default to glossary term name"
      )
    end
    assert_select(
      "form [name='glossary_term[description]']",
      { text: /#{term.description}/, count: 1 },
      "Form lacks Description field that defaults to glossary term description"
    )
    assert_select("input#glossary_term_upload_image", false,
                  "Edit GlossaryTerm form should omit upload image field")
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

    term = GlossaryTerm.last
    assert_equal(params[:glossary_term][:name], term.name)
    assert_equal(params[:glossary_term][:description], term.description)
    assert_not_nil(term.rss_log)
    assert_equal(user.id, term.user_id)
    assert_response(:redirect)
  end

  def test_create_upload_image
    params = term_with_image_params
    login

    assert_difference("Image.count") do
      post(:create, params: params)
    end
    term = GlossaryTerm.last
    assert_equal(Image.last, term.thumb_image)
  end

  def test_create_no_name
    params = create_term_params
    params[:glossary_term][:name] = ""
    login

    assert_no_difference("GlossaryTerm.count") do
      post(:create, params: params)
    end
    assert_flash(/#{:glossary_error_name_blank.t}/)
    assert_response(:success)
  end

  def test_create_no_description_or_image
    params = create_term_params
    params[:glossary_term][:description] = ""
    login

    assert_no_difference("GlossaryTerm.count") do
      post(:create, params: params)
    end
    assert_flash(/#{:glossary_error_description_or_image.t}/)
  end

  def test_create_duplicate_name
    existing_name = GlossaryTerm.first.name
    params = create_term_params
    params[:glossary_term][:name] = existing_name
    login

    assert_no_difference("GlossaryTerm.count") do
      post(:create, params: params)
    end
    assert_flash(
      # Must be quoted because it contains Regexp metacharacters "(" and ")"
      Regexp.new(Regexp.quote(:glossary_error_duplicate_name.t))
    )
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

  def test_update_no_name
    params = changes_to_conic.merge
    params[:glossary_term][:name] = ""
    login

    post(:create, params: params)
    assert_flash(/#{:glossary_error_name_blank.t}/)
  end

  def test_update_no_description_or_image
    params = changes_to_conic.merge
    params[:glossary_term][:description] = ""
    login

    post(:create, params: params)
    assert_flash(/#{:glossary_error_description_or_image.t}/)
  end

  def test_update_duplicate_name
    existing_name = GlossaryTerm.where.not(name: "Conic").first.name
    params = changes_to_conic.merge
    params[:glossary_term][:name] = existing_name
    login

    post(:update, params: params)
    assert_flash(
      # Must be quoted because it contains Regexp metacharacters "(" and ")"
      Regexp.new(Regexp.quote(:glossary_error_duplicate_name.t))
    )
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

  # ---------- helpers ---------------------------------------------------------

  def assert_title(title)
    assert_select("head title", { text: /#{title}/, count: 1 },
                  "Incorrect page or page title displayed")
  end

  def create_term_params
    {
      glossary_term: { name: "Xevnoc", description: "Convex spelled backward" },
      copyright_holder: "Insil Choi",
      date: { copyright_year: "2013" },
      upload: { license_id: licenses(:ccnc30).id }
    }.freeze
  end

  def changes_to_conic
    {
      id: glossary_terms(:conic_glossary_term).id,
      glossary_term: { name: "Xevnoc", description: "Convex spelled backward" },
      copyright_holder: "Insil Choi",
      date: { copyright_year: 2013 },
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
