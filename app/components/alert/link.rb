# frozen_string_literal: true

class Components::Alert::Link < Components::Base
  def initialize(text, href, class: nil, **attrs)
    super()
    @text = text
    @href = href
    @html_class = grab(class:)
    @attrs = attrs
  end

  def view_template
    render(Components::Link::Get.new(
             name: @text,
             target: @href,
             class: class_names("alert-link", @html_class),
             **@attrs
           ))
  end
end
