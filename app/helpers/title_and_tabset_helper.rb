# frozen_string_literal: true

# --------- contextual nav ------------------------------------------------
#  --- links and buttons ----
#
#  title_tag_contents           # text to put in html header <title>
#  link_next                    # link to next object
#  link_prev                    # link to prev object
#  create_links                 # convert links into list of tabs
#  draw_tab_set
#

module TitleAndTabsetHelper
  # contents of the <title> in html header
  def title_tag_contents(title:, action_name:)
    if title.present?
      title.strip_html
    elsif TranslationString.where(tag: "title_for_#{action_name}").present?
      :"title_for_#{action_name}".t
    else
      action_name.tr("_", " ").titleize
    end
  end

  # link to next object in query results
  def link_next(object)
    path = if object.class.controller_normalized?
             if object.type_tag == :rss_log
               send(:activity_log_path, object.id, flow: "next")
             else
               send("#{object.type_tag}_path", object.id, flow: "next")
             end
           else
             { controller: object.show_controller,
               action: :show, id: object.id }
           end
    link_with_query("#{:FORWARD.t} »", path)
  end

  # link to previous object in query results
  def link_prev(object)
    path = if object.class.controller_normalized?
             if object.type_tag == :rss_log
               send(:activity_log_path, object.id, flow: "prev")
             else
               send("#{object.type_tag}_path", object.id, flow: "prev")
             end
           else
             { controller: object.show_controller,
               action: :show, id: object.id }
           end
    link_with_query("« #{:BACK.t}", path)
  end

  # Convert an array (of arrays) of link attributes into an array of HTML tabs
  # that may be either links or CRUD button_to's, for RHS tab set
  # Example
  # links = [
  #   ["text", "url", { class: "edit_form_link" }],
  #   [nil, article, { button: :destroy }]
  # ]
  # create_tabs(links) will make an array of the following HTML
  #   "<a href="url" class="edit_form_link">text</a>",
  #   "(an HTML form)" via destroy_button, gives default button text and class
  #
  def create_tabs(links)
    return [] unless links

    links.compact.map do |str, url, args|
      args ||= {}
      kwargs = args&.except(:button, :target)
      case args[:button]
      when :destroy
        destroy_button(name: str, target: args[:target] || url, **kwargs)
      when :post
        post_button(name: str, path: url, **kwargs)
      when :put
        put_button(name: str, path: url, **kwargs)
      when :patch
        patch_button(name: str, path: url, **kwargs)
      else
        link_to(str, url, kwargs)
      end
    end
  end

  # Short-hand to render shared tab_set partial for a given set of links.
  def draw_tab_set(links)
    render(partial: "layouts/content/tab_set", locals: { links: links })
  end

  def index_sorter(sorts)
    return "" unless sorts

    render(partial: "layouts/content/sorter", locals: { sorts: sorts })
  end
end
