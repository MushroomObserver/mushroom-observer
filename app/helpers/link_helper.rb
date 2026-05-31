# frozen_string_literal: true

#  link_with_query              # link_to with query params
#  destroy_button               # button to destroy object
#  post_button                  # button to post to a path
#
#  TO USE CAPTURE &BLOCK
#  content = block_given? ? capture(&block) : name
#  probably need content.html_safe.
#  https://stackoverflow.com/questions/1047861/how-do-i-create-a-helper-with-block
#  heads up about button_to input vs button
#  https://blog.saeloun.com/2021/08/24/rails-7-button-to-rendering

module LinkHelper
  # Call `link_to` with query params added.
  # Should now take exactly the same args as `link_to`.
  # You can pass a hash to `path`, but not separate args. Can take a block.
  def link_with_query(text = nil, path = nil, **opts, &block)
    link = block ? text : path # first two positional, if block then path first
    content = block ? capture(&block) : text

    link_to(add_q_param(link), opts) { content }
  end

  # https://stackoverflow.com/questions/18642001/add-an-active-class-to-all-active-links-in-rails
  # https://stackoverflow.com/questions/75742517/how-to-highlight-active-nav-link-when-using-hotwire
  # Make a link that is a target for the stimulus "nav-active_controller"
  # (The controller adds .active class if it's a link to the current page,
  # and updates the active link when navigating. Allows nav to be cached!)
  def active_link_to(text = nil, path = nil, **opts, &block)
    link = block ? text : path # because positional
    content = block ? capture(&block) : text
    opts[:data] = (opts[:data] || {}).merge(
      { nav_active_target: "link", action: "nav-active#navigate" }
    )

    link_to(link, opts) { content }
  end

  # mixes in "active" class
  def active_link_with_query(text = nil, path = nil, **, &block)
    link = block ? text : path # because positional
    content = block ? capture(&block) : text

    active_link_to(add_q_param(link), **) { content }
  end

  # Link should be to a controller action that renders the form in the modal.
  # Stimulus modal-toggle controller fetches the form from the link as a .
  # turbo-stream response. It also checks if it needs to generate a modal, or
  # just show the one in progress.
  # NOTE: Needs a modal `identifier`, in case of multiple form modals
  # NOTE: Args from an MO "tab" will be a hash.
  # Links with data-turbo-frame do a direct page update, and if turbo doesn't
  # find the frame already on the page it's appended after body! That may be
  # why it's appended to the page and not returned to the stimulus caller
  def modal_link_to(identifier, name, path, args)
    args = args.deep_merge({ data: {
                             modal: "modal_#{identifier}",
                             controller: "modal-toggle",
                             action: "modal-toggle#showModal:prevent"
                           } })

    if args[:icon].present?
      icon_link_to(name, path, **args)
    else
      link_to(name, path, **args)
    end
  end

  # Icon link with optional active state. (Tooltip title must be
  # swapped in JS.) Takes same args as `link_to`, e.g.
  # `icon_link_to(text, path, **args)`. Can also print a `button_to`
  # via `button_to: true`. Delegates to `Components::IconLink` —
  # render the component directly in Phlex views.
  def icon_link_to(text = nil, path = nil, options = {}, &block)
    return unless text

    link_path = block ? text : path # positional: block ⇒ first arg is path
    content = block ? capture(&block) : text
    opts = block ? path : options

    render(Components::IconLink.new(content, link_path, **opts))
  end

  # NOTE: above re: MO tabs
  def icon_link_with_query(text = nil, path = nil, options = {}, &block)
    return unless text

    link = block ? text : path # because positional
    content = block ? capture(&block) : text
    opts = block ? path : options

    icon_link_to(add_q_param(link), opts) { content }
  end

  # Glyphicon `<span>` with the MO `link-icon` class. Pass `title:`
  # for a tooltip + screen-reader label. Delegates to
  # `Components::LinkIcon` — render the component directly in Phlex
  # views.
  def link_icon(type, **args)
    return "" unless LINK_ICON_INDEX[type]

    render(Components::LinkIcon.new(
             type: type,
             title: args[:title],
             html_class: args[:class],
             data: args[:data] || {},
             attributes: args.except(:title, :class, :data)
           ))
  end

  def external_link(link)
    case link.external_site.name
    when "iNaturalist"
      concat(
        link_to(
          "iNat #{link.url.sub(link.external_site.base_url, "")}", link.url
        )
      )
    else
      concat(link_to(:on_site.t(site: link.external_site.name), link.url))
      concat(tag.small(" #{link.created_at.web_date}"))
    end
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

  # button to destroy object
  # Used instead of link_to because method: :delete requires jquery_ujs library
  # Sample usage:
  #   destroy_button(target: article)
  #   destroy_button(name: :destroy_object.t(type: :glossary_term),
  #                  target: term)
  #   destroy_button(
  #     name: :destroy_object.t(type: :herbarium),
  #     target: herbarium_path(@herbarium,
  #     back: herbaria_path(@herbarium.try(&:id)))
  #   )
  #
  def destroy_button(target:, name: nil, **args)
    render(Components::CrudButton::Delete.new(
             target: target, name: name, **args
           ))
  end

  # GET-style edit link — emits `<a>` (link_to), not a form-wrapped
  # button. Delegates to `Components::CrudButton::Edit`, which carries
  # the `action: :edit`/`icon: :edit` defaults and (for model targets
  # rendered from SHOW_OBS_EDITABLES controllers) the `?back=show|index`
  # query param. Callers wanting a text-only edit link pass `icon: nil`.
  def edit_button(target:, name: nil, **args)
    render(Components::CrudButton::Edit.new(
             target: target, name: name, **args
           ))
  end

  # GET-style download link for a species_list — emits `<a>` via
  # `Components::CrudButton::Download`. The path is built explicitly
  # as a String because the route shape doesn't match
  # `download_<resource>_path` — there's a `new_download_species_list`
  # named route, but `download_species_list` is the index path.
  def download_button(target:, name: nil, **args)
    render(Components::CrudButton::Download.new(
             target: new_download_species_list_path(id: target.id),
             name: name,
             **args
           ))
  end

  # Refactor to accept a tab array

  # POST to a path; used instead of a link because POST link requires js
  def post_button(name:, path:, **args, &block)
    render(Components::CrudButton::Post.new(
             name: name, target: path, **args, &block
           ))
  end

  # PUT to a path; used instead of a link because PUT link requires js
  def put_button(name:, path:, **args, &block)
    render(Components::CrudButton::Put.new(
             name: name, target: path, **args, &block
           ))
  end

  # PATCH to a path; used instead of a link because PATCH link requires js
  def patch_button(name:, path:, **args, &block)
    render(Components::CrudButton::Patch.new(
             name: name, target: path, **args, &block
           ))
  end
end
