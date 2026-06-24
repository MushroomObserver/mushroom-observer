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

  private

  def render_it(html_id: "results")
    render(
      Class.new(Components::Base) do
        define_method(:_html_id) { html_id }

        def view_template
          render(::Components::PaginatedResults.new(html_id: _html_id)) do
            plain("content")
          end
        end
      end.new
    )
  end
end
