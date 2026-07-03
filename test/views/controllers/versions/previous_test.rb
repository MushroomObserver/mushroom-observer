# frozen_string_literal: true

require "test_helper"

class Views::Controllers::Versions::PreviousTest < ComponentTestCase
  def test_renders_panel_with_type_tagged_id
    name = names(:peltigera)

    html = render(
      Views::Controllers::Versions::Previous.new(
        obj: name, versions: name.versions.to_a
      )
    )

    # Panel id is `<type_tag>_versions` — e.g. `name_versions`.
    assert_html(html, "##{name.type_tag}_versions")
  end

  def test_renders_one_row_per_version_in_reverse_order
    name = names(:peltigera)

    html = render(
      Views::Controllers::Versions::Previous.new(
        obj: name, versions: name.versions.to_a
      )
    )

    # The latest version's anchor carries `latest_version_link`; the
    # remaining anchors carry `initial_version_link`.
    assert_html(html, "a.latest_version_link")
  end

  def test_bold_args_callable_emboldens_matching_rows
    # `args[:bold]` is a callable that decides per-row whether to wrap
    # the version label in `<strong>`. The name-versions page uses it
    # to embolden non-deprecated rows.
    name = names(:peltigera)
    versions = name.versions.to_a

    html = render(
      Views::Controllers::Versions::Previous.new(
        obj: name, versions: versions,
        args: { bold: ->(_v) { true } }
      )
    )

    assert_html(html, "a strong")
  end
end
