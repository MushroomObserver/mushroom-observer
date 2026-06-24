# frozen_string_literal: true

require("test_helper")

module Tab::Image
  class TabsTest < UnitTestCase
    def routes
      Rails.application.routes.url_helpers
    end

    def setup
      @image = images(:in_situ_image)
      @name = names(:coprinus_comatus)
    end

    def test_edit
      tab = Tab::Image::Edit.new(image: @image)

      assert_equal(:edit_object.t(type: :image), tab.title)
      assert_equal(routes.edit_image_path(@image.id), tab.path)
      assert_equal(@image, tab.model)
    end

    def test_destroy
      tab = Tab::Image::Destroy.new(image: @image)

      assert_equal(:destroy_object.t(type: :image), tab.title)
      assert_equal(@image, tab.path)
      assert_equal(:destroy, tab.html_options[:button])
    end

    def test_eol
      eol_url = "https://eol.org/pages/12345"
      Triple.create!(subject: @image.show_url,
                     predicate: @image.eol_predicate,
                     object: eol_url)
      tab = Tab::Image::Eol.new(image: @image)

      assert_equal("EOL", tab.title, "EOL tab title")
      assert_equal(eol_url, tab.path, "EOL tab path delegates to eol_url")
      assert(tab.html_options[:external], "EOL tab opens in new tab")
    end

    def test_commercial_inquiry
      tab = Tab::Image::CommercialInquiry.new(image: @image)

      assert_equal(:image_show_inquiry.t, tab.title)
      assert_equal(
        routes.new_commercial_inquiry_for_image_path(@image.id), tab.path
      )
      assert_equal(@image, tab.model)
    end

    def test_name_google_images
      tab = Tab::Image::NameGoogleImages.new(name: @name)

      assert_equal(:google_images.t, tab.title)
      assert(tab.path.start_with?("http://images.google.com/images?q="))
      assert_includes(tab.path, @name.search_name)
      assert(tab.html_options[:external])
    end
  end
end
