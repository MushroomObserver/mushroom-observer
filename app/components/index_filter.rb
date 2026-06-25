# frozen_string_literal: true

# Bootstrap-3 inline index filter form — `<form class="form-inline">`
# wrapping a flex row that holds the caller's field(s) plus a submit
# button. Used for narrow GET-method filters on index pages where the
# user picks a value (text, autocompleter, etc.) and submits to
# refine the visible list.
#
# Renders a plain Phlex `<form method="get">` — no Superform / no
# FormObject — because filter forms just rewrite the index URL with
# the new params. GET forms don't need CSRF, and the index
# controllers already read filter params (e.g. `params[:project]`)
# directly off the URL, so there's nothing to gain from a model-
# bound submit.
#
# Caller renders the field(s) inside the block — typically via
# `Components::ApplicationForm::FieldProxy` + the field component
# (e.g. `AutocompleterField`) so the autocompleter widget is
# reachable without wrapping the whole page in a Superform.
#
# Bootstrap-3 layout the shell owns:
# - `.form-inline` on `<form>` (the right element per BS3 spec)
# - `.d-flex.gap-2.align-items-end` row inside, so siblings align
#   to the input's baseline regardless of whether the field has a
#   label-on-top stack (autocompleters do; plain inputs may)
#
# @example Autocompleter filter (Phlex view)
#   field = Components::ApplicationForm::FieldProxy.new(
#             nil, :project_name, @title
#           )
#   render(Components::IndexFilter.new(
#            to: field_slips_path, submit_text: :FILTER.l
#          )) do
#     render(Components::ApplicationForm::AutocompleterField.new(
#              field, type: :project, hidden_name: :project,
#              inline: true, size: 60,
#              label: "#{:field_slip_filter_by.l}:"
#            ))
#   end
class Components::IndexFilter < Components::Base
  include Components::ButtonStyling

  # Submit target — either a route helper's String path or a Rails-
  # style routing Hash (`{ controller:, action:, … }`). `url_for`
  # normalizes either shape into the `<form action="…">` string.
  prop :to, _Union(String, Hash)
  prop :submit_text, String
  prop :form_id, _Nilable(String), default: nil
  prop :extra_class, _Nilable(String), default: nil

  def view_template(&block)
    form(action: url_for(@to), method: "get",
         class: form_class, id: @form_id) do
      div(class: "d-flex gap-2 align-items-end") do
        yield if block
        render(::Components::Button.new(type: :submit, name: @submit_text,
                                        html_name: "commit"))
      end
    end
  end

  private

  def form_class
    ["form-inline", @extra_class].compact.join(" ")
  end
end
