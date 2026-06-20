# frozen_string_literal: true

require("test_helper")

# `Components::Dropdown` is exercised in production via several
# consumers (`Views::Layouts::Header::Sorter`,
# `Views::Layouts::TopNav::ContextNav`, etc.); their tests
# indirectly cover the Bootstrap-3 dropdown chrome and the
# `Tab::Collection` / `Array` section shapes. This file focuses on
# the two branches in `#normalize_section` that those consumer
# tests don't reach: the `Tab::Base` case and the catch-all `else`.
class DropdownTest < ComponentTestCase
  def setup
    super
    @project = projects(:bolete_project)
  end

  # `menu.section(Tab::Base.new(...))` is the single-tab section
  # shape (used when a dropdown wants to register just one link
  # without wrapping it in a Collection). Exercises the
  # `when ::Tab::Base then [section.to_a]` branch.
  def test_renders_single_tab_base_section
    html = render(Components::Dropdown.new(
                    id: "single_tab_toggle",
                    menu_id: "single_tab_menu",
                    label: "Menu"
                  )) do |menu|
      menu.section(Tab::Project::Summary.new(project: @project))
    end

    assert_html(html, "a.dropdown-toggle[id='single_tab_toggle']")
    assert_html(html, "ul.dropdown-menu[id='single_tab_menu']")
    assert_html(
      html,
      "ul.dropdown-menu li a[href='#{routes.project_path(id: @project.id)}']"
    )
  end

  # Post/put/patch/destroy tuples dispatched through the dropdown must
  # NOT carry `.btn` styling — they should render as plain form-submits
  # inside a `<li>`, not as Bootstrap-styled action buttons.
  # Regression guard for the `style: nil` default added to
  # `Components::LinkRendering#render_crud_button_or_link`.
  def test_post_tuple_renders_without_btn_styling
    html = render_dropdown_with_button(button: :post)

    assert_html(html, "li form")
    assert_no_html(html, "button.btn")
  end

  def test_patch_tuple_renders_without_btn_styling
    html = render_dropdown_with_button(button: :patch)

    assert_html(html, "li form")
    assert_no_html(html, "button.btn")
  end

  def test_put_tuple_renders_without_btn_styling
    html = render_dropdown_with_button(button: :put)

    assert_html(html, "li form")
    assert_no_html(html, "button.btn")
  end

  def test_destroy_tuple_renders_without_btn_styling
    html = render_dropdown_with_button(button: :destroy)

    assert_html(html, "li form")
    assert_no_html(html, "button.btn")
  end

  # Sections that are `nil` (or any unrecognized type) normalize to
  # `[]` and get filtered out by `reject(&:empty?)`. With nothing
  # left to render, the entire dropdown wrapper is suppressed.
  # Exercises the `else []` branch + the early-return in
  # `view_template`.
  def test_nil_section_renders_nothing
    html = render(Components::Dropdown.new(
                    id: "empty_toggle",
                    menu_id: "empty_menu",
                    label: "Empty"
                  )) do |menu|
      menu.section(nil)
    end

    assert_equal("", html)
  end

  private

  def render_dropdown_with_button(button:)
    render(Components::Dropdown.new(
             id: "test_toggle",
             menu_id: "test_menu",
             label: "Menu"
           )) do |menu|
      menu.section([["Action", "/some/path", { button: button }]])
    end
  end
end
