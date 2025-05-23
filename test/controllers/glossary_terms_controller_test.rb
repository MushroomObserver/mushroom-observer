# frozen_string_literal: true

require("test_helper")

# functional tests of glossary controller and views
class GlossaryTermsControllerTest < FunctionalTestCase
  ESSENTIAL_ATTRIBUTES = %w[name description].freeze

  # ---------- Test actions that Display data (index, show, etc.) --------------

  # ***** index *****
  def test_index
    # make sure public can access
    get(:index)

    assert_response(:success)
    assert_head_title(:glossary_term_index_title.l)

    GlossaryTerm.find_each do |term|
      assert_select(
        "a[href *= '#{glossary_term_path(term.id)}']", true,
        "Glossary Index missing link to #{term.unique_text_name})"
      )
    end
  end

  def test_index_by_letter
    # make sure public can access
    term = glossary_terms(:plane_glossary_term)
    get(:index, params: { letter: "P" })
    assert_template("index")
    assert_select(
      "a[href *= '#{glossary_term_path(term.id)}']", true,
      "Glossary Index at `P` missing link to #{term.unique_text_name})"
    )
  end

  def test_index_by_id
    term = glossary_terms(:plane_glossary_term)
    get(:index, params: { id: term.id })
    assert_template("index")
    assert_select(
      "a[href *= '#{glossary_term_path(term.id)}']", true,
      "Glossary Index at `P` missing link to #{term.unique_text_name})"
    )
  end

  def test_glossary_term_search
    conic = glossary_terms(:conic_glossary_term)
    convex = glossary_terms(:convex_glossary_term)

    get(:index, params: { pattern: "conic" })
    qr = QueryRecord.last.id.alphabetize
    assert_redirected_to(glossary_term_path(conic.id, params: { q: qr }))

    get(:index, params: { pattern: conic.id })
    assert_redirected_to(glossary_term_path(conic.id))

    login
    get(:index, params: { pattern: "con" })
    assert_template("index")
    assert_select(
      "a[href*='glossary_terms/#{conic.id}']", text: conic.name
    )
    assert_select(
      "a[href*='glossary_terms/#{convex.id}']", text: convex.name
    )
  end

  # ***** show *****
  def test_show_public
    term = glossary_terms(:square_glossary_term)

    get(:show, params: { id: term.id })

    assert_response(
      :success,
      "Public should be able to view Glossary Terms without logging in"
    )
  end

  def test_show_with_multiple_images
    term = glossary_terms(:plane_glossary_term)
    assert(term.images.size > 1, "Test needs term with multiple images")

    get(:show, params: { id: term.id })

    assert_response(
      :success,
      "Glossary Terms with >1 image should be viewable without logging in"
    )
  end

  def test_show_logged_in
    term = glossary_terms(:square_glossary_term)
    assert_operator(term.version, :>, 1,
                    "Test needs a GlossaryTerm fixture with multiple versions")
    prior_version_path =
      version_of_glossary_term_path(term.id, version: term.version - 1)

    login
    get(:show, params: { id: term.id })

    assert_response(:success)
    assert_head_title(:show_glossary_term_title.l(name: term.name))

    ESSENTIAL_ATTRIBUTES.each do |attr|
      assert_select("body", /#{term.send(attr)}/,
                    "Page is missing glossary term #{attr}")
    end
    assert_select("a[href='#{prior_version_path}']", true,
                  "Page should have link to prior version")
    assert_select(
      "#glossary_term_authors_editors",
      { count: 1,
        text: /Creator.*: #{rolf.name}Editors: #{mary.name}, #{katrina.name}/ }
    )
    assert_select(
      "a[href='https://en.wikipedia.org/w/index.php?search=#{term.name}']",
      true,
      "Glossary Term page should have link to Wikipedia search for the Term"
    )
  end

  def test_show_admin_delete
    term = glossary_terms(:square_glossary_term)
    login
    make_admin
    get(:show, params: { id: term.id })

    assert_select("form input[value='delete']", { count: 1 },
                  "Page is missing a way for admin to destroy glossary term")
  end

  # ---------- Test actions that Display forms -- (new, edit, etc.) ------------

  # ***** new *****
  def test_new
    login
    get(:new)

    assert_response(:success)
    assert_head_title(:create_glossary_term_title.l)

    ESSENTIAL_ATTRIBUTES.each do |attr|
      assert_select("form [name='glossary_term[#{attr}]']", { count: 1 },
                    "Form should have one field for #{attr}")
    end
    assert_select("input#upload_image", { count: 1 },
                  "Form should include upload image field")
  end

  def test_new_no_login
    get(:new)
    assert_response(:redirect,
                    "Unlogged-in user should not be able to create term")
  end

  # ***** edit *****
  def test_edit
    term = glossary_terms(:conic_glossary_term)

    login
    assert(term.can_edit?)

    post(:edit, params: { id: term.id })

    assert_response(:success)
    assert_head_title(:edit_glossary_term_title.l(name: term.name))

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
    assert_select("input#upload_image", false,
                  "Edit GlossaryTerm form should omit upload image field")
    assert_select(
      "#glossary_term_locked", false,
      "GlossaryTerm form should not show `Locked` input to non-admin user"
    )
  end

  def test_edit_no_login
    term = glossary_terms(:conic_glossary_term)

    post(:edit, params: { id: term.id })
    assert_response(:redirect,
                    "Unlogged-in user should not be able to edit term")
  end

  def test_edit_in_admin_mode
    term = glossary_terms(:conic_glossary_term)

    login
    make_admin
    post(:edit, params: { id: term.id })

    assert_response(:success)
    assert_select(
      "#glossary_term_locked", { count: 1 },
      "GlossaryTerm form should show `Locked` input when in admin mode"
    )
  end

  def test_edit_locked_term_by_non_admin
    term = glossary_terms(:locked_glossary_term)

    login
    post(:edit, params: { id: term.id })

    assert_flash_error
    assert_redirected_to(glossary_term_path(term))
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
    existing_name = GlossaryTerm.reorder(created_at: :asc).first.name
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

  def test_create_invalid_name_with_image
    params = term_with_image_params
    params[:glossary_term][:name] = ""
    login

    assert_no_difference("GlossaryTerm.count") do
      assert_no_difference("Image.count") do
        post(:create, params: params)
      end
    end
    assert_flash(/#{:glossary_error_name_blank.t}/)
  end

  def test_create_image_save_failure
    login
    # Simulate image.save failure.
    image = images(:disconnected_coprinus_comatus_image)
    image.stub(:save, false) do
      Image.stub(:new, image) do
        post(:create, params: term_with_image_params)
      end
    end
    assert_empty(GlossaryTerm.last.images)
  end

  def test_create_process_image_failure
    login
    image = images(:disconnected_coprinus_comatus_image)

    # Simulate process_image failure.
    image.stub(:process_image, false) do
      Image.stub(:new, image) do
        post(:create, params: term_with_image_params)
      end
    end

    assert_flash_error
  end

  # ***** update *****
  def test_update
    term = glossary_terms(:conic_glossary_term)
    creator = term.user
    user = mary
    assert_not_equal(user, creator,
                     "Test needs user who didn't create the term.")
    params = changes_to_conic

    login(user.login)
    assert_difference("term.versions.count") do
      post(:update, params: params)
    end
    assert_equal(params[:glossary_term][:name], term.reload.name)
    assert_equal(params[:glossary_term][:description], term.description)
    assert_equal(creator, term.user,
                 "Editing a Term should not change term.user")
    assert_redirected_to(glossary_term_path(term.id))
  end

  def test_update_lock_by_admin
    term = glossary_terms(:conic_glossary_term)
    assert_not(term.locked?, "Test needs an unlocked GlossaryTerm fixture")

    login
    make_admin
    post(:update,
         params: { id: glossary_terms(:conic_glossary_term).id,
                   glossary_term: { locked: true } })

    assert_equal(true, term.reload.locked)
  end

  def test_update_lock_by_non_admin
    term = glossary_terms(:conic_glossary_term)
    assert_not(term.locked?, "Test needs an unlocked GlossaryTerm fixture")

    login
    post(:update,
         params: { id: glossary_terms(:conic_glossary_term).id,
                   glossary_term: { locked: true } })

    assert_equal(false, term.reload.locked)
  end

  def test_update_unlock_by_admin
    term = glossary_terms(:locked_glossary_term)

    login
    make_admin
    post(:update,
         params: { id: glossary_terms(:locked_glossary_term).id,
                   glossary_term: { locked: false } })

    assert_equal(false, term.reload.locked)
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
    delete(:destroy, params: { id: term.id })

    assert_flash_success
    assert_response(:redirect)
    assert_not(GlossaryTerm.exists?(term.id), "Failed to destroy GlossaryTerm")
  end

  def test_destroy_term_has_images
    term = glossary_terms(:unused_thumb_and_used_image_glossary_term)
    unused_image = term.thumb_image
    used_image = term.other_images.first
    assert_equal(1, unused_image.all_subjects.count,
                 "unused_image should only be used by one subject")
    assert_operator(1, "<", used_image.all_subjects.count,
                    "used_image should be used by more than one subject")

    login
    make_admin
    delete(:destroy, params: { id: term.id })

    assert_flash_success
    assert_response(:redirect)
    assert_not(GlossaryTerm.exists?(term.id), "Failed to destroy GlossaryTerm")

    assert_not(Image.exists?(unused_image.id),
               "Failed to destroy unused Image #{unused_image.id}")
    assert(Image.exists?(used_image.id),
           "Image #{used_image.id} which was used elsewhere was destroyed")
  end

  def test_destroy_no_login
    term = GlossaryTerm.reorder(created_at: :asc).first
    login(users(:zero_user).login)
    delete(:destroy, params: { id: term.id })

    assert_flash_text(:permission_denied.l)
    assert_response(:redirect)
    assert(GlossaryTerm.exists?(term.id),
           "Non-admin should not be able to destroy glossary term")
  end

  def test_destroy_fails
    term = glossary_terms(:no_images_glossary_term)

    login
    make_admin
    term.stub(:destroy, false) do
      GlossaryTerm.stub(:safe_find, term) do
        delete(:destroy, params: { id: term.id })
      end
    end

    assert_redirected_to(glossary_term_path(term.id),
                         "It should redisplay a Term it fails to destroy")
  end
  # ---------- helpers ---------------------------------------------------------

  def create_term_params
    {
      glossary_term: { name: "Xevnoc", description: "Convex spelled backward" },
      upload: {
        copyright_holder: "Insil Choi",
        copyright_year: "2013",
        license_id: licenses(:ccnc30).id
      }
    }.freeze
  end

  def changes_to_conic
    {
      id: glossary_terms(:conic_glossary_term).id,
      glossary_term: { name: "Xevnoc", description: "Convex spelled backward" },
      upload: {
        copyright_holder: "Insil Choi",
        copyright_year: 2013,
        license_id: licenses(:ccnc25).id
      }
    }.freeze
  end

  def term_with_image_params
    setup_image_dirs
    file = Rails.root.join("test/images/Coprinus_comatus.jpg")
    file = Rack::Test::UploadedFile.new(file, "image/jpeg")

    {
      glossary_term: {
        name: "Pancake",
        description: "Flat"
      },
      upload: {
        image: file,
        copyright_holder: "zuul",
        copyright_year: 2013,
        when: Time.current,
        license_id: licenses(:ccnc25).id
      }
    }.freeze
  end
end
