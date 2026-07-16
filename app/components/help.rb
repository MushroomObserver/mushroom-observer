# frozen_string_literal: true

# Single entry-point dispatcher for all help-text shapes, and the
# renderable class for the plain `help-block` shape (by far the most
# common) itself. Pass `type:` to dispatch to one of the other, DOM-
# distinct shapes; omit it for the plain shape.
#
#   Help(content: :some_help_text.tp)               # plain, default <div>
#   Help(element: :span, content: "(optional)")     # plain, inline <span>
#   Help(well: true) { render(help_slot) }          # well shape
#   Help(arrow: :up, id: "textile_help") { "..." }  # well + arrow
#   Help(collapse_id: "field_help_x") { "..." }     # collapsible well
#   Help(type: :tooltip, label: "(?)", title: "...")
#   Help(type: :collapse_block, target_id: "help_1") { "..." }
#   Help(type: :collapse_info_trigger, target_id: "help_1")
#
# There used to be a second "note" flavor (`Help::Note`, `:span`
# default element) alongside this "block" one (`Help::Block`, `:div`
# default) as separate classes; merged into this one dispatcher since
# the DOM shape only ever differed by element tag + CSS class, both of
# which `element:` + `render_plain`'s class choice cover directly.
# `element: :span` renders `.help-note` (color only, genuinely
# inline); anything else renders `.help-block` (Bootstrap's own class
# — hardcodes `display: block`, so it must stay off `:span` content or
# the block display forces it onto its own line regardless of tag).
#
# `:tooltip`, `:collapse_block`, and `:collapse_info_trigger` are
# genuinely different DOM shapes (not just a class/tag variation) and
# stay as separate dispatched subclasses (`Components::Help::Tooltip`,
# etc).
#
# Pure kwargs — no positional-arg shorthand. The old
# `Components::Help::Block` / `Help::Note` accepted a legacy
# `(element, string)` positional pair (an ERB-helper holdover); this
# was the last component in the codebase still doing that, everything
# else (`Link`, `Button`, etc.) is kwargs-only, so the merge dropped it.
#
# Renders nothing when there's neither a block nor `content:` to show
# — empty wrappers are noise no caller needs; opt out by not calling
# `Help(...)` at all when you know there's nothing to render.
class Components::Help < Components::Base
  DISPATCH = {
    tooltip: :Tooltip,
    collapse_block: :CollapseBlock,
    collapse_info_trigger: :CollapseInfoTrigger
  }.freeze

  prop :element, Symbol, default: :div
  prop :content, _Nilable(String), default: nil
  prop :well, _Boolean, default: false
  prop :arrow, _Nilable(_Union(:up, :down, "up", "down")), default: nil
  prop :collapse_id, _Nilable(String), default: nil
  prop :extra_class, _Nilable(String), default: nil
  prop :id, _Nilable(String), default: nil
  # No `default:` — `#initialize` always passes `attributes:` via
  # `super`, so the default lambda would be dead code (and a
  # coverage gap).
  prop :attributes, _Hash(_Union(Symbol, String), _Any?)

  # Single-entry-point dispatcher. Pass `type:` to route to one of the
  # DOM-distinct subclasses in `DISPATCH`; omit it for the plain shape.
  def self.new(**kwargs, &block)
    type_sym = kwargs[:type]&.to_sym
    if (klass_name = DISPATCH[type_sym])
      kwargs.delete(:type)
      return const_get(klass_name).new(**kwargs, &block)
    end

    if kwargs.key?(:type)
      raise(ArgumentError.new(
              "Unknown Help type: #{kwargs[:type].inspect}. " \
              "Valid types: #{DISPATCH.keys.join(", ")}."
            ))
    end

    super
  end

  # `arrow:` and `collapse_id:` both imply `well:`. Anything not
  # extracted here (`data:`, `title:`, etc.) flows through to
  # `**attributes` — kept as one `**kwargs` param (rather than
  # naming each as its own keyword param) to stay under RuboCop's
  # `Metrics/ParameterLists` limit.
  def initialize(**kwargs)
    extra_class = kwargs.delete(:class)
    arrow = kwargs.delete(:arrow)
    collapse_id = kwargs.delete(:collapse_id)
    well_implied = !arrow.nil? || !collapse_id.nil?
    super(element: kwargs.delete(:element) || :div,
          content: kwargs.delete(:content),
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
    block || @content.present?
  end

  def render_plain(&block)
    base_class = @element == :span ? "help-note" : "help-block"
    classes = class_names(base_class, @extra_class)
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
    block ? yield : trusted_html(@content)
  end
end
