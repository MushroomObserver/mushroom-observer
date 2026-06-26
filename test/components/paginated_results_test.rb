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
    html = render_it(top: "PGNTN_TOP", bottom: "PGNTN_BTM",
                     block_content: "BLCK_CNTNT")

    inner = Nokogiri::HTML(html).at_css("div#results")
    assert(inner, "Expected to find div#results")
    text = inner.text
    assert_includes(text, "PGNTN_TOP")
    assert_includes(text, "BLCK_CNTNT")
    assert_includes(text, "PGNTN_BTM")
    assert_operator(text.index("PGNTN_TOP"), :<, text.index("BLCK_CNTNT"))
    assert_operator(text.index("BLCK_CNTNT"), :<, text.index("PGNTN_BTM"))
  end

  def test_omits_pagination_strips_when_absent
    html = render_it

    inner = Nokogiri::HTML(html).at_css("div#results")
    assert_equal("content", inner.text.strip)
  end

  private

  def render_it(html_id: "results", top: nil, bottom: nil,
                block_content: "content")
    render(
      Class.new(Components::Base) do
        define_method(:_html_id) { html_id }
        define_method(:_top) { top }
        define_method(:_bottom) { bottom }
        define_method(:_block_content) { block_content }

        def view_template
          # Set content_for from inside the render so Phlex's view
          # context sees the same store the component reads from.
          content_for(:index_pagination_top, _top) if _top
          content_for(:index_pagination_bottom, _bottom) if _bottom
          render(::Components::PaginatedResults.new(html_id: _html_id)) do
            plain(_block_content)
          end
        end
      end.new
    )
  end
end
