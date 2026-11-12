# frozen_string_literal: true

require "test_helper"

class FormOverflowCheckboxListTest < ComponentTestCase
  # OverflowCheckboxList calls @form.checkbox_field, which needs an
  # active Phlex render state -- same TestForm wrapper as
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
    html = render_list(objects: [@proj1, @proj2])

    assert_html(html,
                "input[type='checkbox'][name='observation[project_ids][]']" \
                "[value='#{@proj1.id}']")
    assert_html(html,
                "input[type='checkbox'][name='observation[project_ids][]']" \
                "[value='#{@proj2.id}']")
  end

  def test_checklist_wired_to_overflow_fade_controller
    html = render_list(objects: [@proj1])

    assert_html(html,
                ".overflow-scroll-checklist[data-controller='overflow-fade']")
  end

  def test_sentinel_hidden_field_present
    html = render_list(objects: [@proj1])

    assert_html(
      html,
      "input[type='hidden'][name='observation[project_ids][]'][value='']"
    )
  end

  def test_unchecked_objects_sort_alphabetically_by_title
    # "Bolete Project" < "EOL Project" -- passed in reverse order to
    # prove the component sorts rather than preserving incoming order.
    html = render_list(objects: [@proj1, @proj2])
    doc = Nokogiri::HTML(html)
    checkboxes = doc.css("input[type='checkbox']")

    assert_equal(@proj2.id.to_s, checkboxes.first["value"])
    assert_equal(@proj1.id.to_s, checkboxes.last["value"])
  end

  def test_checked_object_floats_above_alphabetically_earlier_one
    # @proj1 ("EOL Project") sorts after @proj2 ("Bolete Project")
    # alphabetically; checking @proj1 should still float it to the top.
    html = render_list(objects: [@proj1, @proj2], checked_ids: [@proj1.id])
    doc = Nokogiri::HTML(html)
    checkboxes = doc.css("input[type='checkbox']")

    assert_equal(@proj1.id.to_s, checkboxes.first["value"])
    assert_equal(@proj2.id.to_s, checkboxes.last["value"])
  end

  def test_checked_object_rendered_checked
    html = render_list(objects: [@proj1], checked_ids: [@proj1.id])

    assert_html(html, "input[type='checkbox'][value='#{@proj1.id}'][checked]")
  end

  def test_disabled_object_rendered_disabled
    html = render_list(objects: [@proj1], disabled_ids: [@proj1.id])

    assert_html(html,
                "input[type='checkbox'][value='#{@proj1.id}'][disabled]")
  end

  def test_species_list_type
    list = species_lists(:first_species_list)
    html = render_list(type: :species_list, objects: [list])

    assert_html(html,
                "input[type='checkbox']" \
                "[name='observation[species_list_ids][]'][value='#{list.id}']")
  end

  private

  def render_list(objects:, type: :project, checked_ids: [], disabled_ids: [])
    form = TestForm.new(@obs, action: "/observations")
    the_form = form
    form.render_block = proc do
      render(Components::Form::OverflowCheckboxList.new(
               form: the_form,
               type: type,
               form_object_name: "observation",
               objects: objects,
               checked_ids: checked_ids,
               disabled_ids: disabled_ids
             ))
    end
    render(form)
  end
end
