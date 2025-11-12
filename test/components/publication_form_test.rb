# frozen_string_literal: true

require "test_helper"

class PublicationFormTest < UnitTestCase
  include ComponentTestHelper

  def setup
    @user = users(:rolf)
    @publication = publications(:minimal_unknown)

    # Set up controller request context for form URL generation
    controller.request = ActionDispatch::TestRequest.create
  end

  def test_renders_form_with_all_fields
    form = render_component_form

    assert_includes(form, "form-group")
    assert_includes(form, :publication_full.t)
    assert_includes(form, :publication_link.t)
    assert_includes(form, :publication_peer_reviewed.t)
    assert_includes(form, :publication_how_helped.t)
    assert_includes(form, :publication_mo_mentioned.t)
  end

  def test_renders_submit_button
    form = render_component_form

    assert_includes(form, :CREATE.t)
    assert_includes(form, "btn btn-default")
    assert_includes(form, "center-block my-3")
    assert_includes(form, "data-turbo-submits-with")
  end

  def test_form_has_correct_attributes
    form = render_component_form

    assert_includes(form, 'action="/test_form_path"')
    assert_includes(form, 'method="post"')
    assert_includes(form, 'id="publication_form"')
  end

  def test_component_vs_erb_html
    # Component version
    component_html = render_component_form

    # ERB version (what the old form would generate)
    erb_html = render_erb_version

    puts "\n\n=== COMPONENT HTML ==="
    puts component_html
    puts "\n=== ERB HTML ==="
    puts erb_html
    puts "\n==================\n\n"

    # Both should work and contain key elements
    assert(component_html.present?)
    assert(erb_html.present?)

    # Check key elements are present in both
    [:publication_full.t, :publication_link.t,
     :publication_peer_reviewed.t].each do |text|
      assert_includes(component_html, text,
                      "Component missing: #{text}")
      assert_includes(erb_html, text,
                      "ERB missing: #{text}")
    end
  end

  private

  def render_component_form
    form = Components::PublicationForm.new(
      @publication,
      action: "/test_form_path",
      id: "publication_form"
    )
    render(form)
  end

  def render_erb_version
    # Simulate what the old ERB partial would generate
    view_context.form_with(
      model: @publication,
      url: "/test_form_path",
      id: "publication_form"
    ) do |f|
      fields = []

      # Full field (textarea)
      fields << view_context.text_area_with_label(
        form: f,
        field: :full,
        rows: 10,
        label: "#{:publication_full.t}:",
        between: render(Components::HelpNote.new(
                          element: :span,
                          content: :publication_full_help.t
                        ))
      )

      # Link field
      fields << view_context.text_field_with_label(
        form: f,
        field: :link,
        label: "#{:publication_link.t}:"
      )

      # Peer reviewed checkbox
      fields << view_context.check_box_with_label(
        form: f,
        field: :peer_reviewed,
        label: :publication_peer_reviewed.t
      )

      # How helped field
      fields << view_context.text_area_with_label(
        form: f,
        field: :how_helped,
        rows: 10,
        label: "#{:publication_how_helped.t}:"
      )

      # MO mentioned checkbox
      fields << view_context.check_box_with_label(
        form: f,
        field: :mo_mentioned,
        label: :publication_mo_mentioned.t
      )

      # Submit button
      fields << view_context.submit_button(
        form: f,
        button: :CREATE.t,
        center: true
      )

      fields.join.html_safe
    end
  end
end
