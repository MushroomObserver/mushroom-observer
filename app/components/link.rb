# frozen_string_literal: true

# Base class and single entry-point dispatcher for all
# `Components::Link::*` components. Pass `type:` to route to the
# matching subclass; omit for plain-link subclasses that extend this
# class directly.
#
# The `button:` prop is inherited by all Literal-prop subclasses and
# accepted as a kwarg by manual-`initialize` subclasses. Omit for a
# plain unstyled link; pass a variant symbol (e.g. `:default`,
# `:outline`) to frame the link as a Bootstrap button.
#
#   Link(type: :user,           user: @user)
#   Link(type: :location,       location: @location)
#   Link(type: :object,         object: @obs)
#   Link(type: :get,            name: "Show", target: url)
#   Link(type: :edit,           target: @herbarium)
#   Link(type: :new,            target: path, name: :new_thing.t)
#   Link(type: :download,       target: path, name: "CSV")
#   Link(type: :modal,          modal_id: "m", name: "Open", target: url)
#   Link(type: :collapse_toggle, target_id: "div_id")
#   Link(type: :inline_mod,     target: @record, observation: @obs,
#                               user: current_user)
#   Link(type: :inline_add,     modal_id: "m", tab: some_tab)
#   Link(type: :external,       tab: some_tab)
#   Link(type: :icon,           tab: some_tab)
#   Link(type: :active,         content: "Latest",
#                               path: observations_path)
class Components::Link < Components::Base
  include Components::Button::Styling
  include Components::Button::Content

  prop :button, _Nilable(Symbol), default: nil

  DISPATCH = {
    active: :Active,
    collapse_toggle: :CollapseToggle,
    download: :Download,
    edit: :Edit,
    external: :External,
    get: :Get,
    icon: :Icon,
    inline_add: :InlineAdd,
    inline_mod: :InlineMod,
    location: :Location,
    modal: :Modal,
    new: :New,
    object: :Object,
    user: :User
  }.freeze

  def self.new(**kwargs, &block)
    type_sym = kwargs[:type]&.to_sym
    if (klass_name = DISPATCH[type_sym])
      kwargs.delete(:type)
      return const_get(klass_name).new(**kwargs, &block)
    end

    if kwargs.key?(:type)
      raise(ArgumentError.new(
              "Unknown Link type: #{kwargs[:type].inspect}. " \
              "Valid types: #{DISPATCH.keys.join(", ")}."
            ))
    end

    super
  end

  private

  # Returns the btn class string when `button:` is set, or nil for a
  # plain link. Intentionally different from `Button#btn_styling`:
  # nil means "plain link". Pass `:default` for the grey btn-default
  # frame (same as omitting `variant:` on Components::Button).
  def btn_styling
    return nil unless @button
    return nil if @button == :strip
    return class_names("btn", "btn-default") if @button == :default

    class_names("btn", btn_class(@button))
  end
end
