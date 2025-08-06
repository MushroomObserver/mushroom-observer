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

      # We need to get the query to figure out if we're at the first or last
      qr_id = get_query_param
      query = Query.safe_find(qr_id.dealphabetize) if qr_id

      content_for(:prev_next_object) do
        tag.ul(class: "nav navbar-flex") do
          [
            tag.li { show_link_prev(object, query) },
            tag.li { show_link_index(object) },
            tag.li { show_link_next(object, query) }
          ].safe_join
        end
      end
    end

    SHOW_LINK_BTN_CLASSES = %w[navbar-link navbar-left btn btn-lg px-0].freeze

    # link to previous object in query results
    def show_link_prev(object, query)
      disabled = show_prev_is_first?(object, query) ? "disabled opacity-0" : ""
      classes = class_names(SHOW_LINK_BTN_CLASSES, "prev_object_link", disabled)
      type = object.type_tag

      icon_link_to(
        :PREV_OBJECT.t(type: :"#{type.upcase}".l),
        add_query_param(send(show_link_path(type), object.id, flow: "prev")),
        class: classes, icon: :previous, show_text: false
      )
    end

    def show_prev_is_first?(object, query)
      return false unless query

      query.result_ids.first == object.id
    end

    # link to next object in query results
    def show_link_next(object, query)
      disabled = show_next_is_last?(object, query) ? "disabled opacity-0" : ""
      classes = class_names(SHOW_LINK_BTN_CLASSES, "next_object_link", disabled)
      type = object.type_tag

      icon_link_to(
        :NEXT_OBJECT.t(type: :"#{type.upcase}".l),
        add_query_param(send(show_link_path(type), object.id, flow: "next")),
        class: classes, icon: :next, show_text: false
      )
    end

    def show_next_is_last?(object, query)
      return false unless query

      query.result_ids.last == object.id
    end

    def show_link_path(type)
      return :activity_log_path if type == :rss_log

      :"#{type}_path"
    end

    def show_link_index(object)
      classes = class_names(SHOW_LINK_BTN_CLASSES, %w[mx-1 index_object_link])
      icon = show_link_index_icon(object)
      type = object.type_tag.to_s.pluralize

      icon_link_to(
        :INDEX_OBJECT.t(type: :"#{type.upcase}".l),
        add_query_param(object.index_link_args),
        class: classes, icon: icon, show_text: false
      )
    end

    def show_link_index_icon(object)
      case object.type_tag
      when :observation
        :grid
      else
        :list
      end
    end
  end
end
