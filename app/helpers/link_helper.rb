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

  def active_link_with_query(text = nil, path = nil, **opts, &block)
    link = block ? text : path # because positional
    content = block ? capture(&block) : text
    opts[:class] = class_names(opts[:class], { active: current_page?(link) })

    link_to(add_query_param(link), opts) { content }
  end

  # Take a query which can be coerced into a different model, and create a link
  # to the results of that coerced query.  Return +nil+ if not coercable.
  def link_to_coerced_query(query, model)
    link = coerced_query_link(query, model)
    return nil unless link

    link_to(*link)
  end

  # Buttons to change a target object
  # Destroy uses button_to instead of link_to because method: :delete requires
  # Rails to create a whole form around the button, using the jquery_ujs library
  # Sample usage:
  #   destroy_button(target: article)
  #   destroy_button(name: :destroy_object.t(type: :glossary_term),
  #                  target: term)
  #   destroy_button(
  #     name: :destroy_object.t(type: :herbarium),
  #     target: herbarium_path(@herbarium, back: url_after_delete(@herbarium))
  #   )
  # NOTE: button_to with block generates a button, not an input #quirksmode
  #
  def destroy_button(target:, name: :DESTROY.t, **args, &block)
    name = :DESTROY.t if name.blank? # necessary if nil/empty string passed
    content = block ? capture(&block) : ""
    path, identifier = path_and_identifier_from_target(:destroy, target, args)
    args[:class] = class_names(identifier, args[:class])
    args[:data] = { confirm: :are_you_sure.t }.merge(args[:data] || {})
    args[:icon] = "trash"

    button_with_target(name, path, content, method: :delete, **args)
  end

  # Not a <button> element, but an <a> because it's a GET
  def edit_button(target:, name: :EDIT.t, **args, &block)
    content = block ? capture(&block) : ""
    path, identifier = path_and_identifier_from_target(:edit, target, args)
    args[:class] = class_names(identifier, args[:class])
    args[:icon] = "pen-to-square"

    button_with_target(name, path, content, method: :get, **args)
  end

  def button_with_target(name, path, content, method:, **args)
    html_options = {
      method: method,
      class: "", # allows merge overwrite
      data: { toggle: "tooltip", placement: "top",
              title: name }.merge(args[:data] || {})
    }.merge(args.except(:back, :data, :icon))

    button_to(path, html_options) do
      [content, icon("fa-regular", args[:icon], class: "fa-lg")].safe_join
    end
  end

  def path_and_identifier_from_target(action, target, args)
    if target.is_a?(String)
      path = target
      identifier = "" # needs to be supplied in args[:class]
    else
      prefix = action == :destroy ? "" : "#{action}_"
      path_args = args.slice(:back) # adds back arg, or empty hash if blank
      path = add_query_param(send("#{prefix}#{target.type_tag}_path", target.id,
                                  **path_args))
      identifier = "#{action}_#{target.type_tag}_link_#{target.id}"
    end
    [path, identifier]
  end

  # Not a <button> element, but an <a> because it's a GET
  def add_button(path:, name: :ADD.t, **args, &block)
    content = block ? capture(&block) : ""
    html_options = {
      class: "", # usually also btn
      data: { toggle: "tooltip", placement: "top", title: name }
    }.merge(args)

    link_to(path, html_options) do
      [content, icon("fa-regular", "square-plus", class: "fa-lg")].safe_join
    end
  end

  # TODO: Change translations BACK to PREV, or make a BACK TO translation
  # Not a <button> element, but an <a> because it's a GET
  def back_button(path:, name: :BACK.t, **args, &block)
    content = block ? capture(&block) : ""
    html_options = {
      class: "", # usually also btn
      data: { toggle: "tooltip", placement: "top", title: name }
    }.merge(args)

    link_to(path, html_options) do
      [content, icon("fa-regular", "arrow-left", class: "fa-lg")].safe_join
    end
  end

  # POST to a path; used instead of a link because POST link requires js
  def post_button(name:, path:, **args, &block)
    any_method_button(method: :post, name:, path:, **args, &block)
  end

  # PUT to a path; used instead of a link because PUT link requires js
  def put_button(name:, path:, **args, &block)
    any_method_button(method: :put, name:, path:, **args, &block)
  end

  # PATCH to a path; used instead of a link because PATCH link requires js
  def patch_button(name:, path:, **args, &block)
    any_method_button(method: :patch, name:, path:, **args, &block)
  end

  # any_method_button(method: :patch,
  #                   name: herbarium.name.t,
  #                   path: herbarium_path(id: @herbarium.id),
  #                   data: { confirm: :are_you_sure.t })
  # Pass a block and a name if you want an icon with tooltip
  # NOTE: button_to with block generates a button, not an input #quirksmode
  def any_method_button(name:, path:, method: :post, **args, &block)
    content = block ? capture(&block) : name
    tip = content ? { toggle: "tooltip", placement: "top", title: name } : ""
    html_options = {
      method: method,
      class: "", # blank allows merge overwrite
      data: tip
    }.merge(args)

    button_to(path, html_options) { content }
  end
end
