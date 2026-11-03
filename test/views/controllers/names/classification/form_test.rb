# frozen_string_literal: true

require("test_helper")

module Views::Controllers::Names::Classification
  class FormTest < ComponentTestCase
    def test_form_structure
      name = names(:coprinus_comatus)
      html = render_form(name)

      # Form structure and action
      assert_html(html, "form#name_classification_form")
      assert_html(html, "form[action*='/names/#{name.id}/classification']")
      assert_html(html, "button[type='submit']", text: :save.ti)

      # Header and help text
      assert_includes(html, :form_names_classification.t)
      rank = :"rank_#{name.rank.to_s.downcase}".l
      assert_includes(html, :form_names_classification_help.t(rank: rank))

      # One text field per rank above Genus, pre-filled from the
      # parent's existing classification string.
      FormObject::NameClassification::RANKS.each do |rank_name|
        field_name = "name_classification[rank_#{rank_name.downcase}]"
        assert_html(html, "input[type='text'][name='#{field_name}']")
      end
      assert_html(html,
                  "input[name='name_classification[rank_kingdom]']" \
                  "[value='Fungi']")
    end

    def test_blank_ranks_when_classification_is_blank
      name = names(:conocybe_filaris)
      assert_predicate(name.classification, :blank?,
                       "Test needs a name with no classification")

      html = render_form(name)

      assert_html(html,
                  "input[name='name_classification[rank_kingdom]']" \
                  "[value='']")
    end

    def test_clear_button_present_and_wired_to_fields
      name = names(:coprinus_comatus)
      html = render_form(name)

      assert_html(html, "form[data-controller='clear-fields']")
      assert_html(html, "button[data-action='clear-fields#clear']",
                  text: :clear.ti)

      FormObject::NameClassification::RANKS.each do |rank_name|
        field_name = "name_classification[rank_#{rank_name.downcase}]"
        assert_html(html,
                    "input[name='#{field_name}']" \
                    "[data-clear-fields-target='field']")
      end
    end

    private

    def render_form(name)
      render(Form.new(name))
    end
  end
end
