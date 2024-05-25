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
    skip("Implement this after implememting :index")
    license = articles(:premier_article)
    login("rolf")
    make_admin

    get(:show, params: { id: license.id })

    assert_response(:redirect)
    assert_flash_text(:permission_denied.l)
  end

  def test_new
    skip("Under Construction")
  end

  def test_create
    skip("Under Construction")
    login("rolf")
    make_admin

    get(:new)

    assert_response(:success)
    assert_displayed_title(/#{license.display_name}/)  end

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
