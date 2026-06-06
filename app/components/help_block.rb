# frozen_string_literal: true

# Bootstrap `help-block`-styled element.
#
# Two visual shapes, switched by `well:`:
#
# - **Plain** (default): a bare `help-block` wrapper. `element:`
#   defaults to `:div`; callers can pick `:p` / `:span` etc.
# - **Well** (`well: true`, or implied by passing `arrow:`): the
#   form-page variant wrapped in
#   `<div class="well well-sm mb-3 help-block position-relative">`,
#   with an optional pointer arrow sibling
#   (`<div class="arrow-up hidden-xs">`) when `arrow: :up | :down`.
#   Always a `<div>`; `element:` is ignored.
#
# Content comes from either the `string:` prop or a block — the same
# shape as the legacy `PanelHelper#help_block` /
# `#help_block_with_arrow` helpers, now collapsed into one component.
class Components::HelpBlock < Components::Base
  prop :element, Symbol, default: :div
  prop :string, _Nilable(String), default: nil
  prop :well, _Boolean, default: false
  prop :arrow, _Nilable(_Union(:up, :down, "up", "down")), default: nil
  prop :extra_class, _Nilable(String), default: nil
  prop :id, _Nilable(String), default: nil
  prop :attributes, _Hash(_Union(Symbol, String), _Any?),
       default: -> { {} }

  # Match the legacy helper signatures so callers can keep their
  # familiar positional/keyword shape. `arrow:` implies `well:`.
  def initialize(element = :div, string = nil, **kwargs)
    extra_class = kwargs.delete(:class)
    arrow = kwargs.delete(:arrow)
    super(element: element, string: string,
          well: kwargs.delete(:well) || !arrow.nil?, arrow: arrow,
          id: kwargs.delete(:id),
          extra_class: extra_class, attributes: kwargs)
  end

  def view_template(&block)
    if @well
      render_well(&block)
    else
      render_plain(&block)
    end
  end

  private

  def render_plain(&block)
    classes = class_names("help-block", @extra_class)
    send(@element, class: classes, id: @id, **@attributes) do
      emit_content(&block)
    end
  end

  def render_well(&block)
    classes = ["well well-sm mb-3 help-block position-relative"]
    classes << "mt-3" if @arrow.to_s == "up"

    div(class: classes.join(" "), id: @id) do
      emit_content(&block)
      # `hidden-xs` keeps the arrow desktop-only.
      div(class: "arrow-#{@arrow} hidden-xs") if @arrow
    end
  end

  def emit_content(&block)
    if block
      yield
    elsif @string
      trusted_html(@string)
    end
  end
end
