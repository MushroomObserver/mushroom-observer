# frozen_string_literal: true

require("test_helper")

module Views::Controllers::VisualGroups
  class DistinctNamesTest < ComponentTestCase
    def setup
      super
      @visual_group = visual_groups(:visual_group_one)
    end

    def test_renders_a_link_per_distinct_name
      html = render_distinct_names

      assert_html(html, "a", text: "Agaricus campestris")
    end

    def test_uses_path_for_to_build_each_links_target
      html = render_distinct_names

      assert_html(html, "a[href='/test_path/Agaricus campestris']")
    end

    def test_renders_bold_italic_name_markup
      html = render_distinct_names

      assert_html(html, "a b i", text: "Agaricus")
    end

    private

    def render_distinct_names
      render(DistinctNames.new(
               visual_group: @visual_group, user: users(:rolf),
               path_for: ->(name) { "/test_path/#{name}" }
             ))
    end
  end
end
