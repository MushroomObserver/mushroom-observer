# frozen_string_literal: true

require "test_helper"

class FormCheckboxPanelTest < ComponentTestCase
  # CheckboxPanel calls @form.checkbox_field, which needs an active
  # Phlex render state -- same TestForm wrapper as
  # test/components/form/checkbox_collapse_test.rb.
  class TestForm < Components::ApplicationForm
    attr_accessor :render_block

    def view_template
      instance_eval(&render_block) if render_block
    end
  end

  def setup
    super
    @obs = observations(:minimal_unknown_obs)
    @proj1 = projects(:eol_project)
    @proj2 = projects(:bolete_project)
  end

  def test_renders_one_checkbox_per_object
    html = render_panel(objects: [@proj1, @proj2])

    assert_html(html,
                "input[type='checkbox'][name='observation[project_ids][]']" \
                "[value='#{@proj1.id}']")
    assert_html(html,
                "input[type='checkbox'][name='observation[project_ids][]']" \
                "[value='#{@proj2.id}']")
  end

  def test_sentinel_hidden_field_present
    html = render_panel(objects: [@proj1])

    assert_html(
      html,
      "input[type='hidden'][name='observation[project_ids][]'][value='']"
    )
  end

  def test_unchecked_objects_sort_alphabetically_by_title
    # "Bolete Project" < "EOL Project" -- passed in reverse order to
    # prove the component sorts rather than preserving incoming order.
    html = render_panel(objects: [@proj1, @proj2])
    doc = Nokogiri::HTML(html)
    checkboxes = doc.css("input[type='checkbox']")

    assert_equal(@proj2.id.to_s, checkboxes.first["value"])
    assert_equal(@proj1.id.to_s, checkboxes.last["value"])
  end

  def test_checked_object_floats_above_alphabetically_earlier_one
    # @proj1 ("EOL Project") sorts after @proj2 ("Bolete Project")
    # alphabetically; checking @proj1 should still float it to the top.
    html = render_panel(objects: [@proj1, @proj2], checked_ids: [@proj1.id])
    doc = Nokogiri::HTML(html)
    checkboxes = doc.css("input[type='checkbox']")

    assert_equal(@proj1.id.to_s, checkboxes.first["value"])
    assert_equal(@proj2.id.to_s, checkboxes.last["value"])
  end

  def test_checked_object_rendered_checked
    html = render_panel(objects: [@proj1], checked_ids: [@proj1.id])

    assert_html(html, "input[type='checkbox'][value='#{@proj1.id}'][checked]")
  end

  def test_disabled_object_rendered_disabled
    html = render_panel(objects: [@proj1], disabled_ids: [@proj1.id])

    assert_html(html,
                "input[type='checkbox'][value='#{@proj1.id}'][disabled]")
  end

  def test_block_content_renders_before_checkbox_list
    html = render_panel(objects: [@proj1]) do
      view_context.tag.div(id: "extra_block")
    end
    doc = Nokogiri::HTML(html)
    extra_block = doc.at_css("#extra_block")
    checklist = doc.at_css(".overflow-scroll-checklist")

    assert(extra_block, "Expected the block's #extra_block to render")
    assert(checklist, "Expected the checkbox list to render")
    following_divs = extra_block.xpath("following-sibling::div")

    assert_includes(following_divs, checklist,
                    "Expected the checklist to follow the block's content")
  end

  def test_collapsed_by_default_when_nothing_checked
    html = render_panel(objects: [@proj1])

    assert_html(html, ".panel-collapse-trigger[aria-expanded='false']")
  end

  def test_expanded_when_something_checked
    html = render_panel(objects: [@proj1], checked_ids: [@proj1.id])

    assert_html(html, ".panel-collapse-trigger[aria-expanded='true']")
  end

  def test_expanded_override
    html = render_panel(objects: [@proj1], expanded: true)

    assert_html(html, ".panel-collapse-trigger[aria-expanded='true']")
  end

  def test_heading_is_pluralized_translation_of_type
    html = render_panel(objects: [@proj1])

    assert_html(html, ".panel-title", text: :projects.ti)
  end

  def test_species_list_type
    list = species_lists(:first_species_list)
    html = render_panel(type: :species_list, objects: [list])

    assert_html(html,
                "input[type='checkbox']" \
                "[name='observation[species_list_ids][]'][value='#{list.id}']")
  end

  def test_no_help_text_renders_no_help_block
    html = render_panel(objects: [@proj1])

    assert_no_html(html, ".help-block")
  end

  def test_help_text_renders_before_checklist_and_after_block
    html = render_panel(objects: [@proj1], help_text: "Pick some projects") do
      view_context.tag.div(id: "extra_block")
    end
    doc = Nokogiri::HTML(html)
    extra_block = doc.at_css("#extra_block")
    help_block = doc.at_css(".help-block")
    checklist = doc.at_css(".overflow-scroll-checklist")

    assert_includes(help_block.text, "Pick some projects")
    assert_includes(extra_block.xpath("following-sibling::div"), help_block)
    assert_includes(help_block.xpath("following-sibling::div"), checklist)
  end

  private

  def render_panel(objects:, type: :project,
                   checked_ids: [], disabled_ids: [], **extra, &block)
    form = TestForm.new(@obs, action: "/observations")
    the_form = form
    form.render_block = proc do
      render(Components::Form::CheckboxPanel.new(
               form: the_form,
               type: type,
               form_object_name: "observation",
               objects: objects,
               checked_ids: checked_ids,
               disabled_ids: disabled_ids,
               **extra
             ), &block)
    end
    render(form)
  end
end
