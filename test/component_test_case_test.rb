# frozen_string_literal: true

require "test_helper"

# Tests for the helpers defined on ComponentTestCase itself.
class ComponentTestCaseTest < ComponentTestCase
  # --- assert_html_element_equivalent ---

  def test_passes_for_identical_subtree
    html = '<form><input name="x" value="1"></form>'
    assert_html_element_equivalent(html, html, selector: "form")
  end

  def test_passes_when_attribute_order_differs
    expected = '<input name="x" value="1" class="y">'
    actual = '<input class="y" value="1" name="x">'
    assert_html_element_equivalent(expected, actual, selector: "input")
  end

  def test_passes_for_nested_equivalent_structure
    expected = '<div class="wrap"><span data-target="t">hi</span></div>'
    actual = '<div class="wrap"><span data-target="t">hi</span></div>'
    assert_html_element_equivalent(expected, actual, selector: "div")
  end

  def test_fails_for_missing_attribute
    expected = '<input name="x" class="y">'
    actual = '<input name="x">'
    error = assert_raises(Minitest::Assertion) do
      assert_html_element_equivalent(expected, actual, selector: "input")
    end
    assert_match(/missing attributes.*class/, error.message)
  end

  def test_fails_for_unexpected_attribute
    expected = '<input name="x">'
    actual = '<input name="x" id="extra">'
    error = assert_raises(Minitest::Assertion) do
      assert_html_element_equivalent(expected, actual, selector: "input")
    end
    assert_match(/unexpected attributes.*id/, error.message)
  end

  def test_fails_for_different_attribute_value
    expected = '<a href="/old">x</a>'
    actual = '<a href="/new">x</a>'
    error = assert_raises(Minitest::Assertion) do
      assert_html_element_equivalent(expected, actual, selector: "a")
    end
    assert_match(%r{attribute href.*"/old".*"/new"}, error.message)
  end

  def test_fails_for_different_text_content
    expected = "<span>hello</span>"
    actual = "<span>goodbye</span>"
    error = assert_raises(Minitest::Assertion) do
      assert_html_element_equivalent(expected, actual, selector: "span")
    end
    assert_match(/text.*hello.*goodbye/, error.message)
  end

  def test_fails_for_different_child_count
    expected = "<ul><li>a</li><li>b</li></ul>"
    actual = "<ul><li>a</li></ul>"
    error = assert_raises(Minitest::Assertion) do
      assert_html_element_equivalent(expected, actual, selector: "ul")
    end
    assert_match(/child element count 2 != 1/, error.message)
  end

  def test_fails_for_different_element_name
    expected = "<div><span>x</span></div>"
    actual = "<div><p>x</p></div>"
    error = assert_raises(Minitest::Assertion) do
      assert_html_element_equivalent(expected, actual, selector: "div")
    end
    assert_match(/element name.*span.*p/, error.message)
  end

  def test_path_in_error_message_locates_nested_mismatch
    expected = "<form><div><input name=\"a\"></div></form>"
    actual = "<form><div><input name=\"b\"></div></form>"
    error = assert_raises(Minitest::Assertion) do
      assert_html_element_equivalent(expected, actual, selector: "form")
    end
    # Path should include the form > div > input chain
    assert_match(/<form>.*<div>.*<input>/, error.message)
  end

  def test_fails_when_selector_not_found_in_expected
    expected = "<div></div>"
    actual = "<span></span>"
    error = assert_raises(Minitest::Assertion) do
      assert_html_element_equivalent(expected, actual, selector: "span")
    end
    assert_match(/Expected HTML had no element matching/, error.message)
  end

  def test_fails_when_selector_not_found_in_actual
    expected = "<span></span>"
    actual = "<div></div>"
    error = assert_raises(Minitest::Assertion) do
      assert_html_element_equivalent(expected, actual, selector: "span")
    end
    assert_match(/Actual HTML had no element matching/, error.message)
  end

  def test_strips_csrf_token_by_default
    expected = '<form><input name="authenticity_token" type="hidden" ' \
               'value="abc123"></form>'
    actual = '<form><input name="authenticity_token" type="hidden" ' \
             'value="xyz789"></form>'
    assert_html_element_equivalent(expected, actual, selector: "form")
  end

  def test_does_not_strip_csrf_when_disabled
    expected = '<form><input name="authenticity_token" type="hidden" ' \
               'value="abc"></form>'
    actual = '<form><input name="authenticity_token" type="hidden" ' \
             'value="xyz"></form>'
    error = assert_raises(Minitest::Assertion) do
      assert_html_element_equivalent(
        expected, actual, selector: "form", strip_csrf: false
      )
    end
    assert_match(/attribute value.*abc.*xyz/, error.message)
  end

  def test_label_appears_in_failure_message
    expected = "<span>a</span>"
    actual = "<span>b</span>"
    error = assert_raises(Minitest::Assertion) do
      assert_html_element_equivalent(
        expected, actual, selector: "span", label: "demo-label"
      )
    end
    assert_match(/demo-label/, error.message)
  end

  def test_selector_scopes_comparison_so_surrounding_html_ignored
    # Anything outside the selected element should not affect parity.
    expected = "<header>OLD</header><main><p>same</p></main>"
    actual = "<header>NEW</header><main><p>same</p></main>"
    assert_html_element_equivalent(expected, actual, selector: "main")
  end
end
