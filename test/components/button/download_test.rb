# frozen_string_literal: true

require("test_helper")

class ButtonDownloadTest < ComponentTestCase
  def test_target_renders_btn_default_framing
    sl = species_lists(:first_species_list)
    path = routes.new_download_species_list_path(id: sl.id)
    html = render_download(target: path)

    assert_html(html, "a.btn.btn-default[href='#{path}']")
  end

  def test_variant_overrides_default_framing
    sl = species_lists(:first_species_list)
    path = routes.new_download_species_list_path(id: sl.id)
    html = render_download(target: path, variant: :outline)

    assert_html(html, "a.btn.btn-outline-default")
  end

  def test_tab_shortcut_derives_target_and_name
    name = names(:fungi)
    tab = ::Tab::Name::Edit.new(name: name)
    html = render_download(tab: tab)

    assert_html(html, "a.btn[href='#{tab.path}']", text: tab.title.as_displayed)
  end

  private

  def render_download(**)
    render(Components::Button::Download.new(**))
  end
end
