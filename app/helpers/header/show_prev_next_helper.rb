# frozen_string_literal: true

#  add_pager_for(object)        # add a prev/next pager for an object (show)
#  show_link_next               # link to next object
#  show_link_prev               # link to prev object
#  show_link_index(object)      # link to index

module Header
  module ShowPrevNextHelper
    # Previous/next object links for show templates
    def add_pager_for(object)
      return unless object

      content_for(:prev_next_object) do
        tag.ul(class: "nav navbar-flex") do
          [
            tag.li { show_link_prev(object) },
            tag.li { show_link_index(object) },
            tag.li { show_link_next(object) }
          ].safe_join
        end
      end
    end

    # link to previous object in query results
    def show_link_prev(object)
      classes = class_names(
        %w[navbar-link navbar-left btn btn-lg px-0 prev_object_link]
      )
      path = if object.type_tag == :rss_log
               :activity_log_path
             else
               :"#{object.type_tag}_path"
             end

      icon_link_to(
        :PREV.t, add_query_param(send(path, object.id, flow: "prev")),
        class: classes, icon: :previous, show_text: false
      )
    end

    def show_link_index(object)
      classes = class_names(
        %w[navbar-link navbar-left btn btn-lg px-0 mx-1 index_object_link]
      )
      iicon = case object.type_tag
              when :observation
                :grid
              else
                :list
              end

      icon_link_to(
        :INDEX.t, add_query_param(object.index_link_args),
        class: classes, icon: iicon, show_text: false
      )
    end

    # link to next object in query results
    def show_link_next(object)
      classes = class_names(
        %w[navbar-link navbar-left btn btn-lg px-0 next_object_link]
      )
      path = if object.type_tag == :rss_log
               :activity_log_path
             else
               :"#{object.type_tag}_path"
             end

      icon_link_to(
        :NEXT.t, add_query_param(send(path, object.id, flow: "next")),
        class: classes, icon: :next, show_text: false
      )
    end
  end
end
