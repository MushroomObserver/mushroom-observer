# frozen_string_literal: true

module LinkHelper
  # Link should be to a controller action that renders the form in the modal.
  # Stimulus modal-toggle controller fetches the form from the link as a
  # turbo-stream response. It also checks if it needs to generate a modal, or
  # just show the one in progress.
  # NOTE: Needs a modal `identifier`, in case of multiple form modals
  # NOTE: Args from an MO "tab" will be a hash.
  # Links with data-turbo-frame do a direct page update, and if turbo doesn't
  # find the frame already on the page it's appended after body! That may be
  # why it's appended to the page and not returned to the stimulus caller
  # Delegates to `Components::Link::Modal` — render the component
  # directly in Phlex views.
  def modal_link_to(identifier, name, path, args)
    render(Components::Link::Modal.new(identifier, name, path, **args))
  end

  # Icon link with optional active state. (Tooltip title must be
  # swapped in JS.) Takes same args as `link_to`, e.g.
  # `icon_link_to(text, path, **args)`. Can also print a `button_to`
  # via `button_to: true`. Delegates to `Components::Link::Icon` —
  # render the component directly in Phlex views.
  def icon_link_to(text = nil, path = nil, options = {}, &block)
    return unless text

    link_path = block ? text : path # positional: block ⇒ first arg is path
    content = block ? capture(&block) : text
    opts = block ? path : options

    render(Components::Link::Icon.new(content, link_path, **opts))
  end

  # Glyphicon `<span>` with the MO `link-icon` class. Pass `title:`
  # for a tooltip + screen-reader label. Delegates to
  # `Components::Icon` — render the component directly in Phlex
  # views.
  def link_icon(type, **args)
    return "" unless LINK_ICON_INDEX[type]

    render(Components::Icon.new(
             type: type,
             title: args[:title],
             html_class: args[:class],
             data: args[:data] || {},
             attributes: args.except(:title, :class, :data)
           ))
  end

  # NOTE: Specific to glyphicons
  LINK_ICON_INDEX = {
    edit: "edit",
    delete: "remove-circle",
    add: "plus",
    back: "step-backward",
    show: "eye-open",
    hide: "eye-close",
    reuse: "share",
    x: "remove",
    remove: "remove-circle",
    send: "send",
    log_in: "log-in",
    log_out: "log-out",
    admin: "text-background",
    inbox: "inbox",
    interests: "bullhorn",
    settings: "cog",
    ban: "ban-circle",
    plus: "plus-sign",
    minus: "minus-sign",
    trash: "trash",
    cancel: "remove",
    email: "envelope",
    question: "question-sign",
    alert: "alert",
    list: "list",
    copy: "copy",
    clone: "duplicate",
    merge: "transfer",
    move: "random",
    adjust: "resize-vertical",
    make_default: "star",
    publish: "upload",
    check: "ok-circle",
    deprecate: "ok-circle", # approved name needs to look "approved"
    approve: "exclamation-sign", # deprecated name needs to look "deprecated"
    synonyms: "random",
    tracking: "bullhorn",
    manage_lists: "indent-left",
    observations: "tags",
    print: "print",
    globe: "globe",
    find_on_map: "screenshot",
    apply: "check",
    chevron_down: "chevron-down",
    chevron_up: "chevron-up",
    chevron_left: "chevron-left",
    chevron_right: "chevron-right",
    qrcode: "qrcode",
    mobile: "phone",
    project: "th-list",
    download: "download-alt",
    new_window: "new-window",
    search: "search",
    prev: "triangle-left",
    next: "triangle-right",
    goto: "share-alt",
    grid: "th",
    menu: "align-justify",
    info: "question-sign"
  }.freeze
end
