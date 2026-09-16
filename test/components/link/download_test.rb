# frozen_string_literal: true

require("test_helper")

class LinkDownloadTest < ComponentTestCase
  def test_target_path_renders_default_download_name_and_icon
    sl = species_lists(:first_species_list)
    path = routes.new_download_species_list_path(id: sl.id)
    html = render_download(target: path)

    assert_html(html, "a[href='#{path}']", text: :download.ti.as_displayed)
    assert_html(html, "a svg.mo-icon-download")
  end

  def test_explicit_name_overrides_default
    sl = species_lists(:first_species_list)
    path = routes.new_download_species_list_path(id: sl.id)
    html = render_download(target: path, name: "Go")

    assert_html(html, "a", text: "Go")
  end

  def test_tab_shortcut_uses_tab_title_not_default_download
    name = names(:fungi)
    tab = ::Tab::Name::Edit.new(name: name)
    html = render_download(tab: tab)

    assert_html(html, "a[href='#{tab.path}']", text: tab.title.as_displayed)
    assert_html(html, "a svg.mo-icon-download")
  end

  private

  def render_download(**)
    render(Components::Link::Download.new(**))
  end
end
