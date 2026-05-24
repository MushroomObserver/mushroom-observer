# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Publications
  class FormTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      @publication = Publication.new
    end

    def test_renders_form_with_all_fields
      html = render_component_form

      assert_html(html, ".form-group")
      assert_html(html, "label[for='publication_full']",
                  text: :publication_full.l)
      assert_html(html, "label[for='publication_link']",
                  text: :publication_link.l)
      assert_html(html, "label[for='publication_peer_reviewed']",
                  text: :publication_peer_reviewed.l)
      assert_html(html, "label[for='publication_how_helped']",
                  text: :publication_how_helped.l)
      assert_html(html, "label[for='publication_mo_mentioned']",
                  text: :publication_mo_mentioned.l)
    end

    def test_renders_submit_button
      html = render_component_form

      assert_html(html, "input[type='submit'][value='#{:CREATE.t}']")
      assert_html(html, ".btn.btn-default")
      assert_html(html, ".center-block.my-3")
      assert_html(html, "input[data-turbo-submits-with]")
    end

    def test_form_has_correct_attributes
      html = render_component_form

      # Form auto-determines action for new record
      assert_html(html, "form[action='/publications']")
      assert_html(html, "form[method='post']")
      assert_html(html, "form[id='publication_form']")
    end

    private

    def render_component_form
      render(Form.new(@publication))
    end
  end
end
