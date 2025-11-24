# frozen_string_literal: true

require("test_helper")

class PublicationsControllerTest < FunctionalTestCase
  def test_should_get_index
    get(:index)
    assert_response(:success)
    assert_not_nil(assigns(:publications))
  end

  def test_should_get_index_for_user_who_owns_a_publication
    pub_id = publications(:one_pub).id
    login("rolf")
    get(:index)
    assert_response(:success)
    assert_not_nil(assigns(:publications))
    assert_link_in_html("Edit", action: :edit, id: pub_id)
    assert_link_in_html("Destroy", action: :destroy, id: pub_id)
  end

  def test_should_get_new
    login
    get(:new)
    assert_response(:success)
  end

  def test_should_create_publication
    login
    user = User.current
    ref  = "Author, J.R. 2014. Mushroom Observer Rocks! Some Journal 1(2): 3-4."
    link = "http://some_journal.com/mo_rocks.html"
    help = "it exists"
    assert_difference("Publication.count", +1) do
      post(:create, params: { publication: { full: ref,
                                             link: link,
                                             how_helped: help,
                                             mo_mentioned: true,
                                             peer_reviewed: true } })
    end
    pub = Publication.last
    assert_equal(user.id, pub.user_id)
    assert_equal(ref, pub.full)
    assert_equal(link, pub.link)
    assert_equal(help, pub.how_helped)
    assert_equal(true, pub.mo_mentioned)
    assert_equal(true, pub.peer_reviewed)
    assert_redirected_to(publication_path(assigns(:publication)))
  end

  def test_should_not_create_publication_if_user_not_successful
    login("spamspamspam")
    assert_no_difference("Publication.count") do
      post(:create, params: { publication: {} })
    end
  end

  def test_should_not_create_publication_if_form_empty
    login
    assert_no_difference("Publication.count") do
      post(:create, params: { publication: {} })
    end
  end

  def test_should_show_publication
    get(:show, params: { id: publications(:one_pub).id })
    assert_response(:success)
    login("rolf")
    get(:show, params: { id: publications(:one_pub).id })
    assert_response(:success)
  end

  def test_should_get_edit
    login
    get(:edit, params: { id: publications(:one_pub).id })
    assert_response(:success)
  end

  def test_should_update_publication
    login
    put(:update, params: { id: publications(:one_pub).id, publication: {} })
    assert_redirected_to(publication_path(assigns(:publication)))
  end

  def test_should_destroy_publication
    login
    assert_difference("Publication.count", -1) do
      delete(:destroy, params: { id: publications(:one_pub).id })
    end

    assert_redirected_to(publications_path)
  end

  # HTML format tests for permission/validation failures
  def test_should_not_update_publication_without_permission
    login("mary")
    put(:update, params: { id: publications(:one_pub).id,
                           publication: { full: "New" } })
    assert_redirected_to(publications_path)
  end

  def test_should_not_update_publication_with_errors
    login
    put(:update, params: { id: publications(:one_pub).id,
                           publication: { full: "" } })
    assert_response(:success)
    assert_template(:edit)
  end

  def test_should_not_destroy_publication_without_permission
    login("mary")
    assert_no_difference("Publication.count") do
      delete(:destroy, params: { id: publications(:one_pub).id })
    end
    assert_redirected_to(publications_path)
  end

  # XML format tests for coverage
  def test_should_create_publication_xml
    disable_unsafe_html_filter
    login
    ref = "Author, J.R. 2014. Test Publication."
    assert_difference("Publication.count", +1) do
      post(:create, params: { publication: { full: ref } }, format: :xml)
    end
    assert_response(201) # created
  end

  def test_should_not_create_publication_with_errors_xml
    disable_unsafe_html_filter
    login
    assert_no_difference("Publication.count") do
      post(:create, params: { publication: { full: "" } }, format: :xml)
    end
    assert_response(422) # unprocessable_content
  end

  def test_should_not_update_publication_without_permission_xml
    disable_unsafe_html_filter
    login("mary")
    put(:update, params: { id: publications(:one_pub).id,
                           publication: { full: "New" } }, format: :xml)
    assert_response(422) # unprocessable_content
  end

  def test_should_not_update_publication_with_errors_xml
    disable_unsafe_html_filter
    login
    put(:update, params: { id: publications(:one_pub).id,
                           publication: { full: "" } }, format: :xml)
    assert_response(422) # unprocessable_content
  end

  def test_should_not_destroy_publication_without_permission_xml
    disable_unsafe_html_filter
    login("mary")
    assert_no_difference("Publication.count") do
      delete(:destroy, params: { id: publications(:one_pub).id }, format: :xml)
    end
    assert_response(422) # unprocessable_content
  end
end
