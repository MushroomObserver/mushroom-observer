# frozen_string_literal: true

# Renders a button_to with turbo support and optional confirmation.
# Used as the base for patch_button, post_button, put_button, destroy_button.
#
# Usage:
#   render(Components::AnyMethodButton.new(
#     name: :REMOVE.l,
#     target: @herbarium,  # or a path string
#     method: :patch,
#     confirm: :show_observation_remove_herbarium_record.l,  # dialog title
#     action: :remove,  # optional, for identifier class
#     icon: :remove
#   ))
#
class Components::AnyMethodButton < Components::Base
  def initialize(name:, target:, method: :post, confirm: nil, **args, &block)
    super()
    @name = name
    @target = target
    @method = method
    @confirm = confirm
    @args = args
    @block = block
  end

  def view_template
    @block&.call

    form_data = { turbo: true }
    form_data[:turbo_confirm] = @confirm if @confirm

    button_data = { toggle: "tooltip", placement: "top", title: @name }
    if @confirm
      button_data[:turbo_confirm_title] = @confirm
      button_data[:turbo_confirm_button] = @name
    end

    html_options = {
      method: @method,
      class: class_names(identifier, @args[:class]),
      form: { data: form_data },
      data: button_data
    }.merge(@args.except(:class, :icon, :action))

    button_to(path, html_options) { button_content }
  end

  private

  def button_content
    capture do
      if @args[:icon]
        span(class: "sr-only") { @name }
        trusted_html(link_icon(@args[:icon]))
      else
        plain(@name)
      end
    end
  end

  def path
    if @target.is_a?(String) || @target.is_a?(Hash)
      @target
    else
      target_path
    end
  end

  def identifier
    if @target.is_a?(String) || @target.is_a?(Hash)
      ""
    else
      "#{action}_#{@target.type_tag}_link_#{@target.id}"
    end
  end

  def action
    @args[:action] || @method
  end

  def target_path
    # For model targets, just use the resource path (e.g., herbarium_path)
    # The HTTP method (PATCH, DELETE, etc.) is set separately via method:
    send(:"#{@target.type_tag}_path", @target.id)
  end
end
