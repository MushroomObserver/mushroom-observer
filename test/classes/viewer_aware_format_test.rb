# frozen_string_literal: true

require("test_helper")

class ViewerAwareFormatTest < UnitTestCase
  class Stub
    include ViewerAwareFormat

    attr_accessor :default_viewer

    def initialize(default_viewer: nil)
      @default_viewer = default_viewer
    end
  end

  def test_viewer_aware_unique_format_name_uses_viewer_aware_method
    stub = Stub.new(default_viewer: mary)
    name = names(:coprinus_comatus)

    assert_equal(name.user_unique_format_name(mary),
                 stub.viewer_aware_unique_format_name(name))
  end

  def test_viewer_aware_unique_format_name_falls_back_for_plain_object
    stub = Stub.new
    location = locations(:albion)

    assert_equal(location.unique_format_name,
                 stub.viewer_aware_unique_format_name(location))
  end

  def test_viewer_aware_unique_format_name_explicit_user_overrides_default
    stub = Stub.new(default_viewer: rolf)
    name = names(:coprinus_comatus)

    assert_equal(name.user_unique_format_name(mary),
                 stub.viewer_aware_unique_format_name(name, mary))
  end

  def test_viewer_aware_location_format_scientific_user
    stub = Stub.new
    location = locations(:albion)

    assert_equal(Location.reverse_name(location.name),
                 stub.viewer_aware_location_format(location, roy))
  end

  def test_viewer_aware_location_format_postal_default_viewer
    stub = Stub.new(default_viewer: rolf)
    location = locations(:albion)

    assert_equal(location.name, stub.viewer_aware_location_format(location))
  end

  def test_viewer_aware_location_format_nil_location
    stub = Stub.new(default_viewer: rolf)

    assert_nil(stub.viewer_aware_location_format(nil))
  end
end
