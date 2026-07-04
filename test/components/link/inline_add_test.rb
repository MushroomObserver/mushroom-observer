# frozen_string_literal: true

require("test_helper")

class Components::Link::InlineAddTest < ComponentTestCase
  def setup
    super
    @obs = observations(:detailed_unknown_obs)
  end

  def test_renders_icon_only_add_link
    tab = ::Tab::CollectionNumber::New.new(observation: @obs)

    html = render(Components::Link::InlineAdd.new(
                    modal_id: "collection_number", tab: tab
                  ))

    assert_html(html, "a[data-modal='modal_collection_number'] " \
                      "span.glyphicon-plus")
    assert_html(html, "a span.sr-only", text: tab.title)
  end
end
