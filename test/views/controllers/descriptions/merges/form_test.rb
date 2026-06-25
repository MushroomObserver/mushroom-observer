# frozen_string_literal: true

require "test_helper"

module Views::Controllers::Descriptions::Merges
  class FormTest < ComponentTestCase
    def setup
      super
      @user = users(:rolf)
      # peltigera has multiple descriptions we can merge
      @description = name_descriptions(:peltigera_desc)
    end

    def test_name_description_with_merge_targets
      html = render_form(@description)

      # Form structure
      assert_html(html, "form#merge_descriptions_form")
      assert_html(html, "form[method='post']")
      assert_html(html, "form[action*='/names/descriptions/']")
      assert_html(html, "form[action*='/merges']")

      # Header and help text
      assert_includes(html, :merge_descriptions_merge_header.t)
      assert_includes(html, :merge_descriptions_merge_help.t)

      # Radio buttons for merge targets
      assert_html(html, "input[type='radio']" \
                        "[name='description_move_or_merge[target]']")

      # Delete checkbox (admin can delete)
      assert_html(html, "input[type='checkbox']" \
                        "[name='description_move_or_merge[delete]']")
      assert_includes(html, :merge_descriptions_delete_after.t)

      # Submit button
      assert_html(html, "button[type='submit']", text: :SUBMIT.l)

      # Permission labels: peltigera_alt_desc is public, not default
      assert_includes(html, "(#{:public.l})")
      # peltigera_user_desc is private; rolf is not in reader_groups
      assert_includes(html, "(#{:private.l})")
    end

    def test_name_description_without_merge_targets
      # Find a description that has no other descriptions to merge with
      desc = NameDescription.all.find do |d|
        (d.parent.descriptions - [d]).empty?
      end
      skip("No description without merge targets found") unless desc

      html = render_form(desc)

      # Form still renders
      assert_html(html, "form#merge_descriptions_form")

      # Shows "no others" message instead of radio buttons
      assert_includes(html, :merge_descriptions_no_others.t)

      # No submit button when nothing to merge
      assert_no_html(html, "button[type='submit']")
    end

    def test_description_title_default_and_restricted
      # Merge from alt_desc: targets include peltigera_desc (default)
      # and peltigera_user_desc (restricted for dick, who can read it)
      alt_desc = name_descriptions(:peltigera_alt_desc)
      html = render_form(alt_desc, user: users(:dick))

      assert_includes(html, "(#{:default.l})")
      assert_includes(html, "(#{:restricted.l})")
    end

    def test_location_description_form_action
      desc = location_descriptions(:albion_desc)
      html = render_form(desc)

      assert_html(html, "form[action*='/locations/descriptions/']")
      assert_html(html, "form[action*='/merges']")
    end

    # When the parent has exactly one other description, default_checked?
    # is true and default_target_id pre-selects that lone radio button.
    def test_single_merge_target_auto_selects
      # coprinus_comatus has 2 descriptions: coprinus_comatus_desc and
      # draft_coprinus_comatus. Rendering the form FOR coprinus_comatus_desc
      # leaves draft_coprinus_comatus as the sole merge target.
      desc = name_descriptions(:coprinus_comatus_desc)
      target = name_descriptions(:draft_coprinus_comatus)

      html = render_form(desc)

      # Exactly one merge target rendered, and it is auto-checked.
      assert_html(html, "input[type='radio']" \
                        "[name='description_move_or_merge[target]']",
                  count: 1)
      assert_html(html, "input[type='radio']" \
                        "[name='description_move_or_merge[target]']" \
                        "[value='#{target.id}'][checked]")
    end

    private

    # Sibling reference within the namespace — `Form` resolves to
    # `Views::Controllers::Descriptions::Merges::Form`.
    def render_form(description, user: @user)
      render(Form.new(description, user: user))
    end
  end
end
