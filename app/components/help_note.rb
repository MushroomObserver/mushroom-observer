# frozen_string_literal: true

# Bootstrap `help-note`-styled inline element — smaller / quieter
# than `Components::HelpBlock`. Used for parenthetical hints on
# form fields ("(optional)", "(required)") and for short
# textile-rendered notes that sit next to a section title.
#
# Replaces the `help_note` helper that lived in
# `app/helpers/panel_helper.rb`.
#
# @example Inline `(optional)` marker next to a label
#   render(Components::HelpNote.new("(#{:optional.l})"))
#
# @example Textile-rendered note as a paragraph
#   render(Components::HelpNote.new(
#     :p, :name_approve_deprecate_help.tp
#   ))
class Components::HelpNote < Components::Base
  prop :element, Symbol, default: :span
  prop :string, _Nilable(String), default: nil
  prop :extra_class, _Nilable(String), default: nil
  prop :attributes, _Hash(_Union(Symbol, String), _Any?),
       default: -> { {} }

  # Match the legacy helper's positional shape — callers wrote
  # `help_note(:p, "...", class: "...")` and we want the same call
  # site to work via `Components::HelpNote.new(:p, "...", ...)`.
  def initialize(element = :span, string = nil, **kwargs)
    extra_class = kwargs.delete(:class)
    super(element: element, string: string,
          extra_class: extra_class, attributes: kwargs)
  end

  def view_template(&block)
    classes = class_names("help-note mr-3", @extra_class)
    send(@element, class: classes, **@attributes) do
      if block
        yield
      elsif @string
        trusted_html(@string)
      end
    end
  end
end
