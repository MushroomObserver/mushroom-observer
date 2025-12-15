# frozen_string_literal: true

require("test_helper")

class BannerTest < ActiveSupport::TestCase
  def test_current
    assert_equal(Banner.current, Banner.order(version: :desc).first)
  end
end
