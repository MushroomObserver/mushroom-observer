# frozen_string_literal: true

require "test_helper"

class BannerTest < ActiveSupport::TestCase
  test "current" do
    assert_equal(Banner.current, Banner.order(version: :desc).first)
  end
end
