# frozen_string_literal: true

# Anchor that triggers a Bootstrap modal via the `modal-toggle`
# Stimulus controller. The controller fetches the modal body from
# `path` as a turbo-stream response and shows the modal — if a modal
# is already up under the same `identifier`, it reuses it.
#
# Drop-in equivalent of the long-standing
# `modal_link_to(identifier, name, path, args)` helper in
# `app/helpers/link_helper.rb`. The helper now renders this
# component so existing ERB and Phlex callers keep working unchanged.
#
# If the caller passes an `:icon`, the anchor renders through
# `Components::IconLink` (icon + sr-only label, tooltip, etc.);
# otherwise it's a plain `link_to`.
#
# @example Plain modal link
#   render(Components::ModalLink.new(
#     "comment", "Edit", edit_comment_path(comment)
#   ))
#
# @example Icon-styled modal link
#   render(Components::ModalLink.new(
#     "comment", "Edit", edit_comment_path(comment), icon: :edit
#   ))
#
# @example From a Tab PORO (shortcut)
#   render(Components::ModalLink.new(
#     "user_question_email",
#     tab: Tab::User::EmailQuestion.new(user: @show_user)
#   ))
class Components::ModalLink < Components::Base
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
      render(Components::IconLink.new(@name, @path, **link_args))
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
