# frozen_string_literal: true

#  add_pager_for(object)        # add a prev/next pager for an object (show)
#  link_next                    # link to next object
#  link_prev                    # link to prev object

module TitlePrevNextHelper
  # Previous/next object links for show templates
  def add_pager_for(object)
    return unless object

    content_for(:prev_next_object) do
      tag.ul(class: "nav navbar-nav navbar-right") do
        [
          tag.li { link_prev(object) },
          tag.li { link_index(object) },
          tag.li { link_next(object) }
        ].safe_join
      end
    end
  end

  # link to previous object in query results
  def link_prev(object)
    classes = class_names(
      %w[navbar-link navbar-left btn px-0 prev_object_link]
    )
    path = if object.type_tag == :rss_log
             send(:activity_log_path, object.id, flow: "prev")
           else
             send(:"#{object.type_tag}_path", object.id, flow: "prev")
           end

    icon_link_to(
      :PREV.t, add_query_param(path),
      class: classes, icon: :previous, show_text: false, icon_class: ""
    )
  end

  def link_index(object)
    classes = class_names(
      %w[navbar-link navbar-left btn px-0 mx-2 index_object_link]
    )

    icon_link_to(
      :INDEX.t, add_query_param(object.index_link_args),
      class: classes, icon: :index, show_text: false, icon_class: ""
    )
  end

  # link to next object in query results
  def link_next(object)
    classes = class_names(
      %w[navbar-link navbar-left btn px-0 next_object_link]
    )
    path = if object.type_tag == :rss_log
             send(:activity_log_path, object.id, flow: "next")
           else
             send(:"#{object.type_tag}_path", object.id, flow: "next")
           end

    icon_link_to(
      :NEXT.t, add_query_param(path),
      class: classes, icon: :next, show_text: false, icon_class: ""
    )
  end
end
