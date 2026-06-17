# frozen_string_literal: true

# Bootstrap `help-block`-styled element.
#
# Three visual shapes, switched by props:
#
# - **Plain** (default): a bare `help-block` wrapper. `element:`
#   defaults to `:div`; callers can pick `:p` / `:span` etc.
# - **Well** (`well: true`, or implied by passing `arrow:`): the
#   form-page variant wrapped in
#   `<div class="well well-sm mb-3 help-block position-relative">`,
#   with an optional pointer arrow sibling
#   (`<div class="arrow-up hidden-xs">`) when `arrow: :up | :down`.
#   Always a `<div>`; `element:` is ignored.
# - **Collapsible well** (`collapse_id: "…"`): the well shape
#   wrapped in `<div class="collapse" id="<collapse_id>">` so a
#   sibling `data-toggle="collapse"` trigger (typically built via
#   `Components::Link::Icon` with `type: :question`) can show / hide
#   it. The well shape is forced; `arrow:` is ignored.
#
# Content comes from either the `string:` prop or a block. When
# neither is supplied the component renders nothing (the caller's
# `<%= %>` then has no effect) — empty wrappers are noise that
# the form layout doesn't need.
class Components::Help::Block < Components::Base
  prop :element, Symbol, default: :div
  prop :string, _Nilable(String), default: nil
  prop :well, _Boolean, default: false
  prop :arrow, _Nilable(_Union(:up, :down, "up", "down")), default: nil
  # When set, wrap the well in `<div class="collapse" id="…">` so
  # an external `data-toggle="collapse" data-target="#<id>"`
  # trigger can show/hide it. Implies `well: true`.
  prop :collapse_id, _Nilable(String), default: nil
  prop :extra_class, _Nilable(String), default: nil
  prop :id, _Nilable(String), default: nil
  # No `default:` — `#initialize` always passes `attributes:` via
  # `super`, so the default lambda would be dead code (and a
  # coverage gap).
  prop :attributes, _Hash(_Union(Symbol, String), _Any?)

  # Match the legacy helper signatures so callers can keep their
  # familiar positional/keyword shape. `arrow:` and `collapse_id:`
  # both imply `well:`.
  def initialize(element = :div, string = nil, **kwargs)
    extra_class = kwargs.delete(:class)
    arrow = kwargs.delete(:arrow)
    collapse_id = kwargs.delete(:collapse_id)
    well_implied = !arrow.nil? || !collapse_id.nil?
    super(element: element, string: string,
          well: kwargs.delete(:well) || well_implied,
          arrow: arrow, collapse_id: collapse_id,
          id: kwargs.delete(:id),
          extra_class: extra_class, attributes: kwargs)
  end

  def view_template(&block)
    return unless content?(&block)

    if @collapse_id
      render_collapse_wrapper(&block)
    elsif @well
      render_well(&block)
    else
      render_plain(&block)
    end
  end

  private

  def content?(&block)
    block || @string.present?
  end

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

  def render_collapse_wrapper(&block)
    div(class: "collapse", id: @collapse_id) do
      render_well(&block)
    end
  end

  def emit_content(&block)
    block ? yield : trusted_html(@string)
  end
end
