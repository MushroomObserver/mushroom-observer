# frozen_string_literal: true

require("test_helper")

class Components::Help::CollapseInfoTriggerTest < ComponentTestCase
  def test_renders_collapse_link_with_question_icon
    html = render(Components::Help::CollapseInfoTrigger.new(
                    target_id: "help_text_1"
                  ))

    assert_html(html, "a[href='#help_text_1']")
    assert_html(html, "a.info-collapse-trigger")
    assert_html(html, "span.glyphicon-question-sign")
  end

  def test_renders_with_extra_class
    html = render(Components::Help::CollapseInfoTrigger.new(
                    target_id: "help_text_2",
                    extra_class: "custom-trigger"
                  ))

    assert_html(html, "a.info-collapse-trigger.custom-trigger")
  end
end
