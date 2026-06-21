# frozen_string_literal: true

# Legacy modal-trigger link. Kept for `Components::ApplicationForm::
# AutocompleterField`, which passes an HTML `name=` attribute on
# the anchor — a use that conflicts with `Button::ModalToggle`'s
# `name:` kwarg (display text). All other callers use
# `Components::Button::ModalToggle` instead.
class Components::Link::Modal < Components::Base
  attr_reader :identifier, :name, :path, :args

  def initialize(identifier, name = nil, path = nil, tab: nil, **args)
    super()
    @identifier = identifier
    if tab
      @name = tab.title
      @path = tab.path
      @args = tab.html_options
    else
      @name = name
      @path = path
      @args = args
    end
  end

  def view_template
    if @args[:icon].present?
      render(Components::Link::Icon.new(@name, @path, **link_args))
    else
      link_to(@name, @path, **link_args)
    end
  end

  private

  def link_args
    @args.deep_merge(data: modal_data)
  end

  def modal_data
    {
      modal: "modal_#{@identifier}",
      controller: "modal-toggle",
      action: "modal-toggle#showModal:prevent"
    }
  end
end
