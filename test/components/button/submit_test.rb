# frozen_string_literal: true

require("test_helper")

class Components::Button::SubmitTest < ComponentTestCase
  def test_renders_button_with_submit_type_and_default_style
    html = render(Components::Button::Submit.new(name: "Save"))

    assert_html(html, "button[type='submit'].btn.btn-default", text: "Save")
  end

  def test_default_disable_with_matches_name
    html = render(Components::Button::Submit.new(name: "Save"))

    assert_html(html, "button[data-disable-with='Save']")
  end

  def test_explicit_disable_with_overrides_name
    html = render(Components::Button::Submit.new(
                    name: "Save",
                    disable_with: "Saving…"
                  ))

    assert_html(html, "button[data-disable-with='Saving…']")
    assert_no_html(html, "button[data-disable-with='Save']")
  end

  def test_submits_with_emits_turbo_data_attr
    html = render(Components::Button::Submit.new(
                    name: "Save",
                    submits_with: "Saving…"
                  ))

    assert_html(html, "button[data-turbo-submits-with='Saving…']")
  end

  def test_accepts_style_override
    html = render(Components::Button::Submit.new(
                    name: "Create",
                    style: :primary
                  ))

    assert_html(html, "button[type='submit'].btn-primary")
    assert_no_html(html, "button.btn-default")
  end

  def test_accepts_size
    html = render(Components::Button::Submit.new(
                    name: "Go",
                    size: :sm
                  ))

    assert_html(html, "button.btn.btn-default.btn-sm[type='submit']")
  end
end
