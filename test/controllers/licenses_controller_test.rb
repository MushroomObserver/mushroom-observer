require "test_helper"

class LicensesControllerTest < FunctionalTestCase
  # ---------- Actions to Display data (index, show, etc.) ---------------------

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
  end

  def test_index_non_admin
    login("rolf")

    get(:index)

    assert_response(:redirect)
    assert_flash_text(:permission_denied.l)
  end

  def test_show
    license = licenses(:publicdomain)
    login("rolf")
    make_admin

    get(:show, params: { id: license.id })

    assert_response(:success)
    assert_displayed_title(/#{license.display_name}/)
  end

  def test_show_non_admin
    license = licenses(:publicdomain)
    login("rolf")

    get(:show, params: { id: license.id })

    assert_response(:redirect)
    assert_flash_text(:permission_denied.l)
  end

  def test_show_non_existent_license
    license = articles(:premier_article)
    login("rolf")
    make_admin

    get(:show, params: { id: license.id })

    assert_response(:redirect)
    assert_flash_text(
      :runtime_object_not_found.l(type: :license.l, id: license.id)
    )
  end

  def test_new
    login("rolf")
    make_admin

    get(:new)

    assert_response(:success)
    assert_form_action(action: :create) # "new" form posts to :create action
  end

  def test_create
    display_name = "Creative Commons Non-commercial v4.0"
    assert_blank(License.where(display_name: display_name),
                 "License already exists")
    form_name = "ccbyncsa40"
    url = "http://creativecommons.org/licenses/by-nc-sa/4.0/"
    params = { display_name: display_name,
               url: url,
               form_name: form_name,
               deprecated: "false" }

    login("rolf")
    make_admin

    assert_difference("License.count", 1, "Failed to create License") do
      post(:create, params: params)
    end

    license = License.last
    assert_equal(display_name, license.display_name)
    assert_equal(form_name, license.form_name)
    assert_equal(url, license.url)
    assert_false(license.deprecated)

    assert_redirected_to(license_path(license.id))
  end

  def test_create_duplicate
    license = licenses(:ccnc30)
    params = { display_name: license.display_name,
               url: license.url,
               form_name: license.form_name,
               deprecated: license.deprecated }

    login("rolf")
    make_admin

    assert_no_difference("License.count", "Created duplicate License") do
      post(:create, params: params)
    end
  end

  def test_create_missing_attribute
    license = licenses(:ccnc30)
    params = { display_name: nil,
               url: license.url,
               form_name: license.form_name,
               deprecated: license.deprecated }

    login("rolf")
    make_admin

    assert_no_difference("License.count", "Created duplicate License") do
      post(:create, params: params)
    end
  end

  def test_edit
    skip("Under Construction")
  end

  def test_update
    skip("Under Construction")
  end

  def test_delete
    skip("Under Construction")
  end
end
