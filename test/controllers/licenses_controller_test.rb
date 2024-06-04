# frozen_string_literal: true

require "test_helper"

class LicensesControllerTest < FunctionalTestCase
  def test_index
    login("rolf")
    make_admin

    get(:index)
    assert(:success, "Admin should be able to see licenses index")
    License.find_each do |license|
      assert_select(
        "a[href *= '#{license_path(license.id)}']", true,
        "full License Index missing link to " \
        "#{license.display_name} (##{license.id})"
      )
    end
    assert_select(
      "a[href = '#{new_license_path}']", true,
      "License Index missing link to #{:create_license_title.l}"
    )
  end

  def test_index_non_admin
    login("rolf")

    get(:index)

    assert_response(:redirect)
    assert_flash_text(:permission_denied.l)
  end

  def test_show
    license = licenses(:publicdomain)
    assert(Image.where(license: license).any?,
           "Need License fixture that's used")
    login("rolf")
    make_admin

    get(:show, params: { id: license.id })

    assert_response(:success)
    assert_displayed_title(/#{license.display_name}/)
    assert_select(
      "a[href = '#{licenses_path}']", true, "License page missing link to Index"
    )
    assert_select(
      "a[href = '#{new_license_path}']", true,
      "License page missing link to add License"
    )
    assert_select(
      "a[href = '#{edit_license_path(license.id)}']", true,
      "License page missing link to edit License"
    )
    assert_select(
      "button", { text: "Destroy", count: 0 },
      "Show page for License in use should not have Destroy button"
    )
  end

  def test_show_unused_license
    license = licenses(:unused)
    login("rolf")
    make_admin

    get(:show, params: { id: license.id })

    assert_response(:success)
    assert_displayed_title(/#{license.display_name}/)
    assert_select(
      "a[href = '#{licenses_path}']", true, "License page missing link to Index"
    )
    assert_select(
      "a[href = '#{new_license_path}']", true,
      "License page missing link to add License"
    )
    assert_select(
      "a[href = '#{edit_license_path(license.id)}']", true,
      "License page missing link to edit License"
    )
    assert_select(
      "button", { text: "Destroy", count: 1 },
      "Show page for unused License in use should have Destroy button"
    )
  end

  def test_show_non_admin
    license = licenses(:publicdomain)
    login("rolf")

    get(:show, params: { id: license.id })

    assert_response(:redirect)
    assert_flash_text(:permission_denied.l)
  end

  def test_show_non_existent_license
    # non-existent id for a License
    license_id = observations(:minimal_unknown_obs).id
    login("rolf")
    make_admin

    get(:show, params: { id: license_id })

    assert_response(:redirect)
    assert_flash_text(
      :runtime_object_not_found.l(type: :license.l, id: license_id)
    )
  end

  def test_new
    login("rolf")
    make_admin

    get(:new)

    assert_response(:success)
    assert_form_action(action: :create) # "new" form posts to :create action
    assert_select(
      "a[href = '#{licenses_path}']", true, "License page missing link to Index"
    )
    assert_select(
      "input[type=checkbox][name='deprecated'][checked='checked']", false,
      "New License form `deprecated` checkbox should be unchecked"
    )
  end

  def test_create
    display_name = "Creative Commons Non-commercial v4.0"
    assert_blank(License.where(display_name: display_name),
                 "License already exists")
    form_name = "ccbyncsa40"
    url = "http://creativecommons.org/licenses/by-nc-sa/4.0/"
    params = { license: { display_name: display_name,
                          url: url,
                          form_name: form_name },
               deprecated: "0" }

    login("rolf")
    make_admin

    assert_difference("License.count", 1, "Failed to create License") do
      post(:create, params: params)
    end

    # Licenses lack created_at column; use updated_at instead
    license = License.order(updated_at: :asc).last
    assert_equal(display_name, license.display_name)
    assert_equal(form_name, license.form_name)
    assert_equal(url, license.url)
    assert_false(license.deprecated)

    assert_flash_success
    assert_redirected_to(license_path(license.id))
  end

  def test_create_duplicate
    license = licenses(:ccnc30)
    params = { license: { display_name: license.display_name,
                          url: license.url,
                          form_name: license.form_name },
               deprecated: (license.deprecated ? "1" : "0") }

    login("rolf")
    make_admin

    assert_no_difference("License.count", "Created duplicate License") do
      post(:create, params: params)
    end
    assert_flash_warning
  end

  def test_create_missing_attribute
    license = licenses(:ccnc30)
    params = { license: { display_name: nil,
                          url: license.url,
                          form_name: license.form_name },
               deprecated: (license.deprecated ? "1" : "0") }

    login("rolf")
    make_admin

    assert_no_difference(
      "License.count", "License is missing `display_name`"
    ) do
      post(:create, params: params)
    end
    assert_flash_warning
  end

  def test_edit
    license = licenses(:ccnc25)
    assert_true(license.deprecated,
                "Test needs a License fixture which is deprecated")
    params = { id: license.id }

    login("rolf")
    make_admin

    get(:edit, params: params)

    assert_response(:success)
    assert_form_action({ action: :update }, "Edit form should post to :update")
    assert_select(
      "a[href = '#{licenses_path}']", true,
      "License edit page missing link to Index"
    )
    assert_select(
      "input[type=checkbox][name='deprecated'][checked='checked']", true,
      "License form `Deprecated` checkbox should be checked"
    )
  end

  def test_update
    license = licenses(:ccwiki30)
    params = { id: license.id,
               license: { display_name: "X Special",
                          form_name: "X",
                          url: "https://x.com/explore" },
               deprecated: "1" }

    login("rolf")
    make_admin

    put(:update, params: params)
    license.reload

    assert_flash_success
    assert_redirected_to(license_path(license.id))

    assert_equal(params.dig(:license, :display_name), license.display_name)
    assert_equal(params.dig(:license, :form_name), license.form_name)
    assert_equal(params.dig(:license, :url), license.url)
    assert_equal((params[:deprecated] == "1"), license.deprecated)
  end

  def test_update_no_changes
    license = licenses(:ccwiki30)
    params = { id: license.id,
               license: { display_name: license.display_name,
                          form_name: license.form_name,
                          url: license.url },
               deprecated: license.deprecated ? "1" : "0" }

    login("rolf")
    make_admin

    put(:update, params: params)

    assert_flash_text(:runtime_edit_name_no_change.l)
    assert_form_action({ action: :update }, "Failed to re-render edit")
  end

  def test_update_missing_attribute
    license = licenses(:ccnc30)
    params = { id: license.id,
               license: { display_name: nil,
                          url: license.url,
                          form_name: license.form_name },
               deprecated: (license.deprecated ? "1" : "0") }

    login("rolf")
    make_admin

    put(:update, params: params)
    assert(license.reload.display_name, "License is missing display_name")
    assert_flash_warning
  end

  def test_update_duplicate_attribute
    license = licenses(:ccnc30)
    params = { id: license.id,
               license: { display_name: license.display_name,
                          # duplicates another license's attribute
                          url: licenses(:ccnc25).url,
                          form_name: license.form_name },
               deprecated: (license.deprecated ? "1" : "0") }

    login("rolf")
    make_admin

    put(:update, params: params)

    assert_flash_text(:runtime_license_duplicate_attributed.l)
    assert_form_action({ action: :update }, "Failed to re-render edit")
  end

  def test_destroy
    license = licenses(:unused)
    params  = { id: license.id }

    login("rolf")
    make_admin

    assert_difference("License.count", -1, "Failed to destroy License") do
      delete(:destroy, params: params)
    end
    assert_flash_success

    assert_not(
      License.exists?(license.id),
      "Failed to destroy license #{license.id}, '#{license.form_name}'"
    )
  end

  def test_destroy_license_in_use
    license = licenses(:ccnc30)
    params  = { id: license.id }

    login("rolf")
    make_admin

    assert_no_difference(
      "License.count", "Destroyed License that's being used"
    ) do
      delete(:destroy, params: params)
    end
    assert(
      License.exists?(license.id),
      "Destroyed license #{license.id}, '#{license.form_name}'"
    )
  end
end
