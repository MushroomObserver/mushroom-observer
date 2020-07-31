# frozen_string_literal: true

require "test_helper"

class PublicationsControllerTest < FunctionalTestCase
  def test_index
    get :index
    assert_response :success
    assert_not_nil assigns(:publications)
    Publications.find_each do |publication|
      assert_select("a[href*='#{publications_path}/#{publication.id}']",
                    { text: publication.title },
                    "Publications Index should link to each publication, " \
                    "including #{publication.title} (##{publication.id})")
    end

    pub_id = publications(:one_pub).id
    login("rolf")
    get :index
    assert_link_in_html("Edit", action: :edit, id: pub_id)
    assert_link_in_html("Destroy", action: :destroy, id: pub_id)
  end

  def test_new
    login
    get :new
    assert_response :success
    assert_select("a", { text: :cancel_and_show.t },
                  "Page is missing a link to cancel creation of publication")
  end

  def test_create
    login
    create_with_empty_form

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
    assert_redirected_to publication_path(assigns(:publication))
  end

  def create_with_empty_form
    assert_no_difference(
      "Publication.count",
      "Publication should not be created by empty form"
    ) do
      post :create, publication: {}
    end
  end

  def test_show
    get :show, id: publications(:one_pub).id
    assert_response :success
    login("rolf")
    get :show, id: publications(:one_pub).id
    assert_response :success
  end

  def test_edit
    login
    get :edit, id: publications(:one_pub).id
    assert_response :success
  end

  def test_update
    login
    put :update, id: publications(:one_pub).id, publication: {}
    assert_redirected_to publication_path(assigns(:publication))
  end

  def test_destroy
    login
    assert_difference("Publication.count", -1) do
      delete :destroy, id: publications(:one_pub).id
    end

    assert_redirected_to publications_path
  end
end
