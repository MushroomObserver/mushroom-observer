# frozen_string_literal: true

require("test_helper")

module Views::Layouts
  class TimestampsTest < ComponentTestCase
    def setup
      super
      @object = collection_numbers(:coprinus_comatus_coll_num)
    end

    # Default `wrap: true` — wraps in `Components::ContentPadded`
    # (`<div class="p-3 small">`).
    def test_renders_with_wrap
      html = render(Timestamps.new(object: @object))

      assert_html(html, "div.p-3 p")
      assert_includes(html, :CREATED_AT.l)
      assert_includes(html, :UPDATED_AT.l)
    end

    # `wrap: false` — caller-supplied padding; component just emits
    # the `<p>` with the dates.
    def test_renders_without_wrap
      html = render(Timestamps.new(object: @object, wrap: false))

      assert_html(html, "p")
      assert_no_html(html, "div.p-3")
    end
  end
end
