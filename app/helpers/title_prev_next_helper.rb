# frozen_string_literal: true

#  add_pager_for(object)        # add a prev/next pager for an object (show)
#  link_next                    # link to next object
#  link_prev                    # link to prev object

module TitlePrevNextHelper
  # Previous/next object links for show templates
  def add_pager_for(object)
    content_for(:prev_next_object) do
      render(partial: "application/content/prev_next_pager",
             locals: { object: object })
    end
  end

  # used by application/content/prev_next_pager
  # link to next object in query results
  def link_next(object)
    path = if object.type_tag == :rss_log
             send(:activity_log_path, object.id, flow: "next")
           else
             send(:"#{object.type_tag}_path", object.id, flow: "next")
           end
    link_with_query("#{:NEXT.t} »", path)
  end

  # link to previous object in query results
  def link_prev(object)
    path = if object.type_tag == :rss_log
             send(:activity_log_path, object.id, flow: "prev")
           else
             send(:"#{object.type_tag}_path", object.id, flow: "prev")
           end
    link_with_query("« #{:PREV.t}", path)
  end
end
