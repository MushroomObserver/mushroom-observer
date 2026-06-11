# frozen_string_literal: true

# Bootstrap-3 inline filter form shell — `<form class="form-inline">`
# wrapping a flex row that holds the caller's field(s) plus a submit
# button. Used for narrow GET-method filters on index / edit pages
# where the user picks a value (text, autocompleter, etc.) and
# submits to refine the visible list.
#
# Inherits from `Components::ApplicationForm` (Superform-backed) and
# is generic over the caller's FormObject — the caller defines the
# attribute(s) being filtered on, instantiates a FormObject carrying
# the current value(s), and passes both the FormObject and a block
# rendering the field(s) bound to that FormObject. The shell owns
# the `<form>` tag, the `.form-inline` chrome, the inner flex row,
# and the submit button.
#
# Canonical Bootstrap-3 layout the shell owns:
# - `.form-inline` on `<form>` (the right element per BS3 spec)
# - `.d-flex.gap-2.align-items-end` row inside, so siblings align
#   to the input's baseline regardless of whether the field has a
#   label-on-top stack (autocompleters do; plain inputs may)
#
# Method: GET. The shell is for filter forms; mutate-state forms
# should use a regular ApplicationForm subclass with method: POST.
#
# @example Autocompleter filter (Phlex view)
#   filter = FormObject::FieldSlipFilter.new(project_name: @title)
#   render(Components::InlineFilterForm.new(
#            filter,
#            url: field_slips_path,
#            submit_text: :FILTER.l
#          )) do |f|
#     f.autocompleter_field(:project_name, type: :project,
#                                          hidden_name: :project,
#                                          inline: true, size: 60,
#                                          label: "#{:field_slip_filter_by.l}:")
#   end
class Components::InlineFilterForm < Components::ApplicationForm
  def initialize(model, url:, submit_text:, form_id: nil, **attributes)
    @url = url
    @submit_text = submit_text
    # `class: "form-inline"` + `method: :get` flow into Superform's
    # `@attributes` and become the rendered `<form>` tag's class /
    # method. `id:` is conditional so it never emits an empty
    # `id=""` attribute. Manual string-concat instead of
    # `class_names` because Rails view helpers aren't reachable
    # until rendering starts.
    extra = attributes[:class]
    attributes[:class] = extra ? "form-inline #{extra}" : "form-inline"
    attributes[:id] = form_id if form_id
    super(model, method: :get, **attributes)
  end

  def form_action
    @url
  end

  def view_template(&block)
    div(class: "d-flex gap-2 align-items-end") do
      yield(self) if block
      input(type: "submit", name: "commit", value: @submit_text,
            class: "btn btn-default")
    end
  end
end
