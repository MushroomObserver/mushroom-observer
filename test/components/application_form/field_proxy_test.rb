# frozen_string_literal: true

require "test_helper"

# Tests for Components::ApplicationForm::FieldProxy and
# .image_field_proxy.
class FieldProxyTest < ComponentTestCase
  # FieldProxy tests
  def test_field_proxy_generates_correct_dom_attributes
    proxy = Components::ApplicationForm::FieldProxy.new(
      "observation[good_image][123]", :notes, "some notes"
    )

    assert_equal(:notes, proxy.key)
    assert_equal("some notes", proxy.value)
    assert_equal("observation_good_image_123_notes", proxy.dom.id)
    assert_equal("observation[good_image][123][notes]", proxy.dom.name)
    assert_equal("some notes", proxy.dom.value)
  end

  def test_field_proxy_with_blank_namespace
    proxy = Components::ApplicationForm::FieldProxy.new("", :field_name, "val")

    assert_equal("field_name", proxy.dom.id)
    assert_equal("field_name", proxy.dom.name)
  end

  def test_field_proxy_with_nil_value
    proxy = Components::ApplicationForm::FieldProxy.new("ns", :field, nil)

    assert_equal("", proxy.dom.value)
  end

  # image_field_proxy class method tests
  def test_image_field_proxy_creates_correct_namespace
    proxy = Components::ApplicationForm.image_field_proxy(
      :good_image, 789, :notes, "test notes"
    )

    assert_equal(:notes, proxy.key)
    assert_equal("test notes", proxy.value)
    assert_equal("observation[good_image][789][notes]", proxy.dom.name)
    assert_equal("observation_good_image_789_notes", proxy.dom.id)
  end

  def test_image_field_proxy_with_image_type
    proxy = Components::ApplicationForm.image_field_proxy(
      :image, 100, :when, "2024-01-01"
    )

    assert_equal("observation[image][100][when]", proxy.dom.name)
  end
end
