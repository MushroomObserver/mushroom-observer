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
      post :create, publication: {
        full: ref,
        link: link,
        how_helped: help,
        mo_mentioned: true,
        peer_reviewed: true
      }
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
      post :create, publication: {}
    end
  end

  def test_should_not_create_publication_if_form_empty
    login
    assert_no_difference("Publication.count") do
      post :create, publication: {}
    end
  end

  def test_should_show_publication
    get(:show, id: publications(:one_pub).id)
    assert_response(:success)
    login("rolf")
    get(:show, id: publications(:one_pub).id)
    assert_response(:success)
  end

  def test_should_get_edit
    login
    get(:edit, id: publications(:one_pub).id)
    assert_response(:success)
  end

  def test_should_update_publication
    login
    put(:update, id: publications(:one_pub).id, publication: {})
    assert_redirected_to(publication_path(assigns(:publication)))
  end

  def test_should_destroy_publication
    login
    assert_difference("Publication.count", -1) do
      delete :destroy, id: publications(:one_pub).id
    end

    assert_redirected_to(publications_path)
  end
end
