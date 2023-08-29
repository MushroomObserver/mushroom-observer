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
  # make a link that has .active class if it's a link to the current page
  def active_link_to(text = nil, path = nil, **opts, &block)
    link = block ? text : path # because positional
    content = block ? capture(&block) : text
    opts[:class] = class_names(opts[:class], { active: current_page?(link) })

    link_to(link, opts) { content }
  end

  # mixes in "active" class
  def active_link_with_query(text = nil, path = nil, **opts, &block)
    link = block ? text : path # because positional
    content = block ? capture(&block) : text

    active_link_to(add_query_param(link), **opts) { content }
  end

  # Take a query which can be coerced into a different model, and create a link
  # to the results of that coerced query.  Return +nil+ if not coercable.
  def link_to_coerced_query(query, model)
    tab = coerced_query_tab(query, model)
    return nil unless tab

    link_to(*tab)
  end

  def icon_link_to(text = nil, path = nil, **opts, &block)
    link = block ? text : path # because positional
    content = block ? capture(&block) : text
    icon_type = opts[:icon]
    return link_to(link, opts) { content } if icon_type.blank?

    opts = { title: content,
             data: { toggle: "tooltip" } }.merge(opts.except(:icon))

    link_to(link, opts) do
      concat(tag.span(content, class: "sr-only"))
      concat(link_icon(icon_type))
    end
  end

  def icon_link_with_query(text = nil, path = nil, **opts, &block)
    link = block ? text : path # because positional
    content = block ? capture(&block) : text

    icon_link_to(add_query_param(link), **opts) { content }
  end

  def link_icon(type)
    return "" unless (glyph = link_icon_index[type])

    tag.span("", class: "glyphicon glyphicon-#{glyph} px-2")
  end

  def link_icon_index
    {
      edit: "edit",
      destroy: "remove-circle",
      add: "plus",
      back: "step-backward",
      hide: "eye-close",
      reuse: "share",
      remove: "minus-sign"
    }.freeze
  end

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
      data: { confirm: :are_you_sure.t,
              toggle: "tooltip", placement: "top", title: name }
    }.merge(args.except(:class, :back))

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
    }.merge(args.except(:class, :back))

    link_to(path, html_options) do
      [content, icon].safe_join
    end
  end

  def button_atts(action, target, args, name)
    if target.is_a?(String)
      path = target
      identifier = "" # can send one via args[:class]
    else
      prefix = action == :destroy ? "" : "#{action}_"
      path_args = args.slice(:back) # adds back arg, or empty hash if blank
      path = add_query_param(send("#{prefix}#{target.type_tag}_path", target.id,
                                  **path_args))
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

  # Note `link_to` - not a <button> element, but an <a> because it's a GET
  def add_button(path:, name: :ADD.t, **args, &block)
    content = block ? capture(&block) : ""
    html_options = {
      class: "", # usually also btn
      data: { toggle: "tooltip", placement: "top", title: name }
    }.merge(args)

    link_to(path, html_options) do
      [content, link_icon(:add)].safe_join
    end
  end

  # TODO: Change translations BACK to PREV, or make a BACK TO translation
  # Note `link_to` - not a <button> element, but an <a> because it's a GET
  def back_button(path:, name: :BACK.t, **args, &block)
    content = block ? capture(&block) : ""
    html_options = {
      class: "", # usually also btn
      data: { toggle: "tooltip", placement: "top", title: name }
    }.merge(args)

    link_to(path, html_options) do
      [content, link_icon(:back)].safe_join
    end
  end

  # POST to a path; used instead of a link because POST link requires js
  # post_button(name: herbarium.name.t,
  #             path: herbaria_merges_path(that: @merge.id,this: herbarium.id),
  #             data: { confirm: :are_you_sure.t })
  def post_button(name:, path:, **args)
    html_options = {
      method: :post,
      class: ""
    }.merge(args)

    button_to(path, html_options) { name }
  end

  # PUT to a path; used instead of a link because PUT link requires js
  # put_button(name: herbarium.name.t,
  #            path: herbarium_path(id: @herbarium.id),
  #            data: { confirm: :are_you_sure.t })
  def put_button(name:, path:, **args)
    html_options = {
      method: :put,
      class: ""
    }.merge(args)

    button_to(path, html_options) { name }
  end

  # PATCH to a path; used instead of a link because PATCH link requires js
  # patch_button(name: herbarium.name.t,
  #              path: herbarium_path(id: @herbarium.id),
  #              data: { confirm: :are_you_sure.t })
  def patch_button(name:, path:, **args)
    html_options = {
      method: :patch,
      class: ""
    }.merge(args)

    button_to(path, html_options) { name }
  end
end
