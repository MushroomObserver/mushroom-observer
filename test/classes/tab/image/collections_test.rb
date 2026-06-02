# frozen_string_literal: true

require("test_helper")

module Tab::Image
  class CollectionsTest < UnitTestCase
    def setup
      @image = images(:in_situ_image)
    end

    def test_show_actions_with_observation_and_permission
      tabs = Tab::Image::ShowActions.new(
        image: @image, permission: true
      ).to_a

      # observation_tabs (3) + eol_tab (if present) + mod_tabs (2)
      # + commercial_tab (if email_general_commercial). The in_situ_image
      # has exactly one observation.
      classes = tabs.map(&:class)
      assert_includes(classes, Tab::Object::Show)
      assert_includes(classes, Tab::Image::NameGoogleImages)
      assert_includes(classes, Tab::Image::Edit)
      assert_includes(classes, Tab::Image::Destroy)
    end

    def test_show_actions_no_permission
      tabs = Tab::Image::ShowActions.new(image: @image).to_a

      classes = tabs.map(&:class)
      assert_not_includes(classes, Tab::Image::Edit)
      assert_not_includes(classes, Tab::Image::Destroy)
    end

    def test_exif_show
      tabs = Tab::Image::EXIFShow.new(image: @image).to_a

      assert_equal([Tab::Object::Return], tabs.map(&:class))
    end

    # Image with no observations: `observation_tabs` returns []; no
    # Show / NameGoogleImages tabs appear, but eol / commercial_tab
    # still can.
    def test_show_actions_no_observations
      orphan = images(:disconnected_coprinus_comatus_image)
      tabs = Tab::Image::ShowActions.new(image: orphan).to_a

      classes = tabs.map(&:class)
      assert_not_includes(classes, Tab::Object::Show)
      assert_not_includes(classes, Tab::Image::NameGoogleImages)
    end

    # Owner opted out of commercial email → CommercialInquiry tab
    # filtered out by `commercial_tab`'s early return. No fixture
    # user has `email_general_commercial: false`, so flip it in-memory.
    def test_show_actions_owner_opted_out_of_commercial
      @image.user.email_general_commercial = false
      tabs = Tab::Image::ShowActions.new(image: @image).to_a

      assert_not_includes(tabs.map(&:class), Tab::Image::CommercialInquiry)
    end

    # Image has an EOL link → `eol_tab` instantiates `Tab::Image::Eol`.
    # No fixture image has an `eol_url` (it requires a Triple record),
    # so stub it on this image to exercise the instantiation branch.
    def test_show_actions_includes_eol_tab_when_image_has_eol_url
      @image.define_singleton_method(:eol_url) { "https://eol.org/foo" }
      tabs = Tab::Image::ShowActions.new(image: @image).to_a

      assert_includes(tabs.map(&:class), Tab::Image::Eol)
    end
  end
end
