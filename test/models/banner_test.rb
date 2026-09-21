# frozen_string_literal: true

require("test_helper")

class BannerTest < ActiveSupport::TestCase
  def test_current
    assert_equal(Banner.current, Banner.order(version: :desc).first)
  end

  def test_next_version
    assert_equal(Banner.maximum(:version) + 1, Banner.next_version)

    Banner.delete_all
    assert_equal(1, Banner.next_version, "the first banner is version 1")
  end
end
