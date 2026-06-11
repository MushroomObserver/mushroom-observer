# frozen_string_literal: true

# Bootstrap-3 inline filter form shell — `<form class="form-inline">`
# wrapping a flex row that holds the caller's field(s) plus the
# submit button. Used for narrow GET-method filters on index/edit
# pages where the user picks a value (text, autocompleter, etc.)
# and submits to refine the visible list.
#
# Canonical Bootstrap-3 layout the shell owns:
# - `.form-inline` on `<form>` (the right element per BS3 spec)
# - `.d-flex.gap-2.align-items-end` row inside, so siblings align
#   to the input's baseline regardless of whether the field has a
#   label-on-top stack (autocompleters do; plain inputs may)
#
# The caller's block receives the FormBuilder so it can render any
# field type — `f.text_field`, `autocompleter_field(form: f, …)`,
# `f.select`, etc.
#
# @example Plain text filter
#   render(Components::InlineFilterFormOld.new(
#            url: edit_visual_group_path(@visual_group),
#            submit_text: :edit_visual_group_update_filter.t)) do |f|
#     # caller renders the field
#   end
#
# @example Autocompleter filter
#   render(Components::InlineFilterFormOld.new(
#            url: field_slips_path,
#            submit_text: "Filter")) do |f|
#     autocompleter_field(form: f, field: :project_name, …)
#   end
class Components::InlineFilterFormOld < Components::Base
  include Phlex::Rails::Helpers::FormWith

  prop :url, String
  prop :submit_text, String
  prop :form_id, _Nilable(String), default: nil

  def view_template(&block)
    form_with(url: @url, method: :get, class: "form-inline",
              id: @form_id) do |f|
      div(class: "d-flex gap-2 align-items-end") do
        yield(f) if block
        input(type: "submit", name: "commit", value: @submit_text,
              class: "btn btn-default")
      end
    end
  end
end
