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
      GlossaryTerm.any_instance.stubs(:reuse).returns(false)
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
      post(:attach, params: params)
      assert_flash_error # Why should this fail? It doesn't at the moment.
    end

    def test_reuse_image_for_glossary_bad_image_id
      glossary_term = glossary_terms(:conic_glossary_term)
      params = { id: glossary_term.id, img_id: "111" }

      post_requires_login(:attach, params)

      assert_flash_text(:runtime_image_reuse_invalid_id.t(id: params[:img_id]))
    end

    def test_remove_images_for_glossary_term
      glossary_term = glossary_terms(:plane_glossary_term)
      params = { id: glossary_term.id }
      requires_login(:remove, params)
      assert_form_action(action: :detach, id: glossary_term.id)
    end
  end
end
