# frozen_string_literal: true

require("test_helper")

class PaginatedResultsTest < ComponentTestCase
  def setup
    super
    controller.define_singleton_method(:q_param) { nil }
    controller.define_singleton_method(:observations_path) do |**|
      "/observations"
    end
  end

  def test_wraps_block_in_results_div
    html = render_it

    assert_html(html, "div#results")
  end

  def test_custom_html_id
    html = render_it(html_id: "my-results")

    assert_html(html, "div#my-results")
    assert_no_html(html, "div#results")
  end

  def test_renders_block_content
    html = render_it

    assert_html(html, "div#results", text: "content")
  end

  def test_data_q_encodes_q_param
    controller.define_singleton_method(:q_param) { "42" }
    html = render_it

    assert_html(html, "div#results[data-q='q=42']")
  end

  def test_weaves_pagination_strips_when_present
    html = render_it(
      top: "PAGINATION_TOP",
      bottom: "PAGINATION_BOTTOM"
    )

    assert_text_in_nested_selector(html, text: "PAGINATION_TOP",
                                         parent: "div#results")
    assert_text_in_nested_selector(html, text: "content",
                                         parent: "div#results")
    assert_text_in_nested_selector(html, text: "PAGINATION_BOTTOM",
                                         parent: "div#results")
    inner = Nokogiri::HTML(html).at_css("div#results").text
    assert_operator(inner.index("PAGINATION_TOP"), :<, inner.index("content"))
    assert_operator(inner.index("content"), :<,
                    inner.index("PAGINATION_BOTTOM"))
  end

  def test_omits_pagination_strips_when_absent
    html = render_it

    assert_text_in_nested_selector(html, text: "content",
                                         parent: "div#results")
  end

  private

  def render_it(html_id: "results", top: nil, bottom: nil)
    render(
      Class.new(Components::Base) do
        define_method(:_html_id) { html_id }
        define_method(:_top) { top }
        define_method(:_bottom) { bottom }

        def view_template
          # Set content_for from inside the render so Phlex's view
          # context sees the same store the component reads from.
          content_for(:index_pagination_top, _top) if _top
          content_for(:index_pagination_bottom, _bottom) if _bottom
          render(::Components::PaginatedResults.new(html_id: _html_id)) do
            plain("content")
          end
        end
      end.new
    )
  end
end
