require "test_helper"

class LicensesControllerTest < FunctionalTestCase
  # ---------- Actions to Display data (index, show, etc.) ---------------------

  def test_list
    skip("Under Construction")
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
