# frozen_string_literal: true

require("test_helper")

class ImagesIntegrationTest < CapybaraIntegrationTestCase
  # ------------------------------------------------------------------------
  #  Quick test to try to catch a bug that the functional tests can't seem
  #  to catch.  (Functional tests can survive undefined local variables in
  #  partials, but not integration tests.)
  # ------------------------------------------------------------------------

  def test_edit_image
    login("mary")
    visit("/images/1/edit")
  end

  def test_show_image_edit_links
    img = images(:in_situ_image)
    proj = projects(:bolete_project)
    assert_equal(mary.id, img.user_id) # owned by mary
    assert(img.projects.include?(proj)) # owned by bolete project
    # dick is only member of project
    assert_equal([mary.id, dick.id], proj.user_group.users.map(&:id))

    login!("rolf")
    visit(image_path(img.id))
    assert_selector("a[href*='#{edit_image_path(img.id)}']", count: 0)
    assert_selector(".destroy_image_link_#{img.id}", count: 0)
    visit(edit_image_path(img.id)) # nope
    assert_selector("body.images__show")

    logout
    login!("mary")
    visit(image_path(img.id))
    assert_selector("a[href*='#{edit_image_path(img.id)}']", minimum: 1)
    assert_selector(".destroy_image_link_#{img.id}", minimum: 1)
    visit(edit_image_path(img.id))
    assert_selector("body.images__edit")

    logout
    login!("dick")
    visit(image_path(img.id))
    assert_selector("a[href*='#{edit_image_path(img.id)}']", minimum: 1)
    assert_selector(".destroy_image_link_#{img.id}", minimum: 1)
    visit(edit_image_path(img.id))
    assert_selector("body.images__edit")
    visit(image_path(img.id))
    click_button(class: "destroy_image_link_#{img.id}")
    assert_flash_success
  end
end
