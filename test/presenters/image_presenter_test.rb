# frozen_string_literal: true

require("test_helper")

# test the presenter for images
class ImagePresenterTest < ActionView::TestCase
  # include ApplicationHelper

  # This test may become unnecessary when covered by other (integration?) tests
  # def test_image_link_html
  #   link = Image.url(:full_size, Image.last.id)
  #   put_link = image_link_html(link, :put)
  #   assert_match(/form class="button_to"/, put_link)
  #   assert_match(/input type="hidden" name="_method" value="put"/,
  #                put_link)
  #   patch_link = image_link_html(link, :patch)
  #   assert_match(/form class="button_to"/, patch_link)
  #   assert_match(/input type="hidden" name="_method" value="patch"/,
  #                patch_link)
  #   delete_link = image_link_html(link, :delete)
  #   assert_match(/form class="button_to"/, delete_link)
  #   assert_match(/input type="hidden" name="_method" value="delete"/,
  #                delete_link)
  # end
end
