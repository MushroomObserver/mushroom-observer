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
  # Call link_to with query params added.
  def link_with_query(name = nil, options = nil, html_options = nil)
    link_to(name, add_query_param(options), html_options)
  end

  # Take a query which can be coerced into a different model, and create a link
  # to the results of that coerced query.  Return +nil+ if not coercable.
  def link_to_coerced_query(query, model)
    link = coerced_query_link(query, model)
    return nil unless link

    link_to(*link)
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
  def destroy_button(target:, name: :DESTROY.t, **args)
    path = if target.is_a?(String)
             target
           else
             add_query_param(send("#{target.type_tag}_path", target.id))
           end
    classes ||= "text-danger"
    id ||= nil
    unless target.is_a?(String)
      classes += " destroy_#{target.type_tag}_link_#{target.id}"
    end

    html_options = {
      method: :delete,
      class: classes,
      id: id,
      data: { confirm: :are_you_sure.t }
    }.merge(args)

    button_to(name, path, html_options)
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

    button_to(name, path, html_options)
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

    button_to(name, path, html_options)
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

    button_to(name, path, html_options)
  end
end
