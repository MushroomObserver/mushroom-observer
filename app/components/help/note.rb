# frozen_string_literal: true

# Bootstrap `help-note`-styled inline element — smaller / quieter
# than `Components::Help::Block`. Used for parenthetical hints on
# form fields ("(optional)", "(required)") and for short
# textile-rendered notes that sit next to a section title.
#
# @example Inline `(optional)` marker next to a label
#   render(Components::Help::Note.new("(#{:optional.l})"))
#
# @example Textile-rendered note as a paragraph
#   render(Components::Help::Note.new(
#     :p, :name_approve_deprecate_help.tp
#   ))
class Components::Help::Note < Components::Base
  prop :element, Symbol, default: :span
  prop :string, _Nilable(String), default: nil
  prop :extra_class, _Nilable(String), default: nil
  # No `default:` — `#initialize` always passes `attributes:` via
  # `super`, so the default lambda would be dead code (and a
  # coverage gap).
  prop :attributes, _Hash(_Union(Symbol, String), _Any?)

  def initialize(element = :span, string = nil, **kwargs)
    extra_class = kwargs.delete(:class)
    super(element: element, string: string,
          extra_class: extra_class, attributes: kwargs)
  end

  def view_template(&block)
    classes = class_names("help-note", @extra_class)
    send(@element, class: classes, **@attributes) do
      if block
        yield
      elsif @string
        trusted_html(@string)
      end
    end
  end
end
