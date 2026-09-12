# frozen_string_literal: true

# Shared rendering helpers for Components::ApplicationForm field-helper
# tests (test/components/application_form/*_test.rb and
# test/components/application_form_test.rb). Every field helper
# (text_field, date_field, checkbox_field, ...) needs a real form/model
# to bind against; these wrap that boilerplate so each field-type test
# file only writes the field call itself.
module ApplicationFormFieldTestHelpers
  # Binds to whatever model the including test's `setup` assigned to
  # `@collection_number` (a CollectionNumber fixture — has `name`/
  # `number` attributes).
  def render_form(turbo: false, &block)
    form = TestFormClass.new(@collection_number,
                             action: "/test_form_path",
                             turbo: turbo)
    form.field_block = block

    render(form)
  end

  def render_upload_form(model, &block)
    form = TestFormClass.new(model, action: "/test_upload_path")
    form.field_block = block

    render(form)
  end

  # Comment has summary/comment/target_id/created_at columns, none of
  # which CollectionNumber (render_form's model) has -- fields that
  # need one of those go through this instead.
  def render_comment_form(model = Comment.new, &block)
    form = TestFormClass.new(model, action: "/test_form_path")
    form.field_block = block

    render(form)
  end

  def render_radio_field(proxy, *options, **field_opts)
    render(Components::ApplicationForm::RadioField.new(
             proxy, *options, **field_opts
           ))
  end

  # Single reusable test form class to avoid duplicate view_template methods
  class TestFormClass < Components::ApplicationForm
    attr_accessor :field_block

    def view_template
      instance_eval(&field_block) if field_block
    end
  end
end
