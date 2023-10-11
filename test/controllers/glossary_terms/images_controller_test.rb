# frozen_string_literal: true

require("test_helper")

# tests of Images controller
module GlossaryTerms
  class ImagesControllerTest < FunctionalTestCase
    def test_reuse_image_page_access
      glossary_term = glossary_terms(:conic_glossary_term)
      params = { id: glossary_term.id }
      requires_login(:reuse, params)
      assert_form_action(action: :attach, id: glossary_term.id)
    end

    def test_reuse_image_page_access__all_images
      glossary_term = glossary_terms(:conic_glossary_term)
      params = { all_users: 1, id: glossary_term.id }
      requires_login(:reuse, params)

      assert_form_action(action: :attach, id: glossary_term.id)
      assert_select("a", { text: :image_reuse_just_yours.l },
                    "Form should have a link to show only the user's images.")
    end

    def test_reuse_image_for_glossary_term_post
      glossary_term = glossary_terms(:conic_glossary_term)
      image = images(:commercial_inquiry_image)
      assert_not(glossary_term.images.member?(image))
      params = {
        id: glossary_term.id.to_s,
        img_id: image.id.to_s
      }
      login("mary")
      post(:attach, params: params)
      assert_redirected_to(glossary_term_path(glossary_term.id))
      assert(glossary_term.reload.images.member?(image))
    end

    def test_reuse_image_for_glossary_term_post_without_thumbnail
      glossary_term = glossary_terms(:convex_glossary_term)
      image = images(:commercial_inquiry_image)
      assert_empty(glossary_term.images)
      assert_nil(glossary_term.thumb_image)
      params = {
        id: glossary_term.id.to_s,
        img_id: image.id.to_s
      }
      login("mary")
      post(:attach, params: params)
      assert_redirected_to(glossary_term_path(glossary_term.id))
      assert(glossary_term.reload.images.member?(image))
      assert_objs_equal(image, glossary_term.thumb_image)
    end

    def test_reuse_image_for_glossary_term_add_image_fails
      glossary_term = glossary_terms(:convex_glossary_term)
      image = images(:commercial_inquiry_image)
      assert_empty(glossary_term.images)
      assert_nil(glossary_term.thumb_image)
      params = {
        id: glossary_term.id.to_s,
        img_id: image.id.to_s
      }
      login("mary")
      get(:reuse, params: { id: glossary_term.id.to_s })
      assert_form_action(action: :attach, id: glossary_term.id)

      # force glossary_term.add_image to fail
      glossary_term.stub(:save, false) do
        GlossaryTerm.stub(:safe_find, glossary_term) do
          post(:attach, params: params)
        end
      end
      assert_flash_error
    end

    def test_reuse_image_for_glossary_bad_image_id
      glossary_term = glossary_terms(:conic_glossary_term)
      params = { id: glossary_term.id, img_id: "111" }

      post_requires_login(:attach, params)

      assert_flash_text(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
    end

    def test_remove_images_from_glossary_term
      glossary_term = glossary_terms(:plane_glossary_term)
      params = { id: glossary_term.id }
      requires_login(:remove, params)
      assert_form_action(action: :detach, id: glossary_term.id)
      assert_not_nil(glossary_term.thumb_image_id)
      assert_equal(glossary_term.user_id, users(:rolf).id)

      put(:detach, params: { id: glossary_term.id.to_s, selected: "" })
      assert_select("#flash_notices.alert",
                    text: :runtime_no_save.t(:glossary_term))

      selected = {}
      selected[glossary_term.thumb_image_id.to_s] = "yes"
      params = {
        id: glossary_term.id.to_s,
        selected: selected
      }

      # Apparently no such thing as no permission to edit a glossary term
      # login("katrina")
      # put(:detach, params: params)
      # assert_flash_error
      # assert_redirected_to(glossary_term_path(glossary_term.id))
      # login("rolf")

      get(:remove, params: { id: glossary_term.id.to_s })
      assert_equal(
        glossary_term.images.length,
        assert_select("img.image-to-remove:not(.img-noscript)").length
      )
      put(:detach, params: params)
      assert_flash_success
      assert_redirected_to(glossary_term_path(glossary_term.id))
    end
  end
end
