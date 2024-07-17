# frozen_string_literal: true

#  link_to_coerced_query        # link to query coerced into different model
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

    link_to(add_query_param(link), opts) { content }
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

    active_link_to(add_query_param(link), **) { content }
  end

  # Take a query which can be coerced into a different model, and create a link
  # to the results of that coerced query.  Return +nil+ if not coercable.
  def link_to_coerced_query(query, model)
    tab = coerced_query_tab(query, model)
    return nil unless tab

    link_to(*tab)
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

  # NOTE: Takes same args as link_to, e.g. *edit_description_tab(desc, type)
  # icon_link_to(text, path, **args)
  def icon_link_to(text = nil, path = nil, options = {}, &block)
    return unless text

    link = block ? text : path # because positional
    content = block ? capture(&block) : text
    opts = block ? path : options
    icon_type = opts[:icon]
    icon_class = class_names(opts[:icon_class], "px-2")
    label_class = if opts[:show_text]
                    "pl-2 d-none d-sm-inline font-weight-bold"
                  else
                    "sr-only"
                  end
    return link_to(link, opts) { content } if icon_type.blank?

    opts = {
      title: content,
      data: { toggle: "tooltip" }
    }.deep_merge(opts.except(:icon, :show_text))

    link_to(link, **opts) do
      concat(link_icon(icon_type, class: icon_class))
      concat(tag.span(content, class: label_class))
    end
  end

  # NOTE: above re: MO tabs
  def icon_link_with_query(text = nil, path = nil, options = {}, &block)
    return unless text

    link = block ? text : path # because positional
    content = block ? capture(&block) : text
    opts = block ? path : options

    icon_link_to(add_query_param(link), opts) { content }
  end

  # pass title if it's a plain button (say for collapse) but you want a tooltip
  def link_icon(type, **args)
    return "" unless (glyph = LINK_ICON_INDEX[type])

    text = ""
    args[:class] = class_names("glyphicon glyphicon-#{glyph} link-icon",
                               args[:class])

    if args[:title].present?
      title = args[:title]
      args[:data] = { toggle: "tooltip", title: }.merge(args[:data] || {})
      text = tag.span(title, class: "sr-only")
    end

    tag.span(text, **args.except(:title))
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
    ban: "ban-circle",
    plus: "plus-sign",
    minus: "minus-sign",
    trash: "trash",
    cancel: "remove",
    email: "envelope",
    question: "question-sign",
    alert: "alert",
    list: "list",
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
    apply: "check"
  }.freeze

  # button to destroy object
  # Used instead of link_to because method: :delete requires jquery_ujs library
  # Sample usage:
  #   destroy_button(target: article)
  #   destroy_button(name: :destroy_object.t(type: :glossary_term),
  #                  target: term)
  #   destroy_button(
  #     name: :destroy_object.t(type: :herbarium),
  #     target: herbarium_path(@herbarium, back: url_after_delete(@herbarium))
  #   )
  #
  def destroy_button(target:, name: :DESTROY.t, **args)
    # necessary if nil/empty string passed
    name = :DESTROY.t if name.blank?
    path, identifier, icon, content = button_atts(:destroy, target, args, name)

    html_options = {
      method: :delete, title: name,
      class: class_names(identifier, args[:class], "text-danger"),
      form: { data: { turbo: true, turbo_confirm: :are_you_sure.t } },
      data: { toggle: "tooltip", placement: "top", title: name }
    }.deep_merge(args.except(:class, :back))

    button_to(path, html_options) do
      [content, icon].safe_join
    end
  end

  # Note `link_to` - not a <button> element, but an <a> because it's a GET
  def edit_button(target:, name: :EDIT.t, **args)
    # necessary if nil/empty string passed
    name = :EDIT.t if name.blank?
    path, identifier, icon, content = button_atts(:edit, target, args, name)

    html_options = {
      class: class_names(identifier, args[:class]), # usually also btn
      title: name, data: { toggle: "tooltip", placement: "top", title: name }
    }.deep_merge(args.except(:class, :back))

    link_to(path, html_options) do
      [content, icon].safe_join
    end
  end

  # Attempts to put together some common button attributes. Overrides available.
  def button_atts(action, target, args, name)
    if target.is_a?(String) || target.is_a?(Hash) # eg { controller:, action: }
      path = target # ignores `action`
      identifier = "" # can send one via args[:class]
    else
      prefix = action == :destroy ? "" : "#{action}_"
      path_args = args.slice(:back) # adds back arg, or empty hash if blank
      path = add_query_param(
        send(:"#{prefix}#{target.type_tag}_path", target.id, **path_args)
      )
      identifier = "#{action}_#{target.type_tag}_link_#{target.id}"
    end
    if args[:icon]
      icon = link_icon(args[:icon])
      content = tag.span(name, class: "sr-only")
    else
      icon = ""
      content = name
    end
    [path, identifier, icon, content]
  end

  # Refactor to accept a tab array
  # Note `link_to` - not a <button> element, but an <a> because it's a GET
  def add_button(path:, name: :ADD.t, **args, &block)
    content = block ? capture(&block) : ""
    html_options = {
      class: "", # usually also btn
      data: { toggle: "tooltip", placement: "top", title: name }
    }.deep_merge(args)

    link_to(path, html_options) do
      [content, link_icon(:add)].safe_join
    end
  end

  # Refactor to accept a tab array
  # TODO: Change translations BACK to PREV, or make a BACK TO translation
  # Note `link_to` - not a <button> element, but an <a> because it's a GET
  def back_button(path:, name: :BACK.t, **args, &block)
    content = block ? capture(&block) : ""
    html_options = {
      class: "", # usually also btn
      data: { toggle: "tooltip", placement: "top", title: name }
    }.deep_merge(args)

    link_to(path, html_options) do
      [content, link_icon(:back)].safe_join
    end
  end

  # Refactor to accept a tab array

  # POST to a path; used instead of a link because POST link requires js
  def post_button(name:, path:, **, &block)
    any_method_button(method: :post, name:, path:, **, &block)
  end

  # PUT to a path; used instead of a link because PUT link requires js
  def put_button(name:, path:, **, &block)
    any_method_button(method: :put, name:, path:, **, &block)
  end

  # PATCH to a path; used instead of a link because PATCH link requires js
  def patch_button(name:, path:, **, &block)
    any_method_button(method: :patch, name:, path:, **, &block)
  end

  # any_method_button(method: :patch,
  #                   name: herbarium.name.t,
  #                   path: herbarium_path(id: @herbarium.id),
  #                   data: { confirm: :are_you_sure.t })
  # Pass a block and a name if you want an icon with tooltip
  # NOTE: button_to with block generates a button, not an input #quirksmode
  def any_method_button(name:, path:, method: :post, **args, &block)
    content = block ? capture(&block) : name
    path, identifier, icon, content = button_atts(method, path, args, name)

    html_options = {
      method: method,
      class: class_names(identifier, args[:class]), # usually also btn
      form: { data: { turbo: true } },
      data: { toggle: "tooltip", placement: "top", title: name }
    }.merge(args) # currently don't have to merge class arg upstream

    button_to(path, html_options) { [content, icon].safe_join }
  end
end
