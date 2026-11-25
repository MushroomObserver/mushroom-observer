# frozen_string_literal: true

require("test_helper")

# tests of Images controller
module GlossaryTerms
  class ImagesControllerTest < FunctionalTestCase
    def test_remove_images_from_glossary_term
      glossary_term = glossary_terms(:plane_glossary_term)
      params = { id: glossary_term.id }
      requires_login(:remove, params)
      assert_form_action(action: :detach, id: glossary_term.id)
      assert_not_nil(glossary_term.thumb_image_id)
      assert_equal(glossary_term.user_id, users(:rolf).id)

      put(:detach, params: { id: glossary_term.id.to_s, selected: "" })
      assert_flash_error(:runtime_no_save, type: :glossary_term)
      assert_unprocessable
      assert_select("form[data-turbo='true']")

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
