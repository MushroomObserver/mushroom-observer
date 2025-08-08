# frozen_string_literal: true

#  Prev/Index/Next object links for show templates
#
#  add_pager_for(object)        # add a prev/next pager for an object (show)
#  show_link_next               # link to next object
#  show_link_prev               # link to prev object
#  show_link_index(object)      # link to index

module Header
  module ShowPrevNextHelper
    # NOTE: Prev/Next only makes sense in the context of a query, so this UI
    # only displays if the current query is for the current type of object,
    # or for :rss_logs. We also need the query to figure out if we're at the
    # first or last, and therefore should hide the prev/next button.
    #
    def add_pager_for(object)
      return unless object && (query = show_page_incoming_query(object))

      content_for(:prev_next_object) do
        tag.ul(class: "nav navbar-flex") do
          [
            tag.li { show_link_prev(object, query) },
            tag.li { show_link_index(object, query) },
            tag.li { show_link_next(object, query) }
          ].safe_join
        end
      end
    end

    # Returns the query if it's for the relevant type of object
    def show_page_incoming_query(object)
      return nil unless params[:q]

      query = Query.safe_find(params[:q].dealphabetize)
      return nil if [object.type_tag, :rss_log].exclude?(query&.type_tag)

      query
    end

    SHOW_LINK_BTN_CLASSES = %w[navbar-link navbar-left btn btn-lg px-0].freeze

    # link to previous object in query results
    def show_link_prev(object, query)
      disabled = show_prev_is_first?(object, query) ? "disabled opacity-0" : ""
      classes = class_names(SHOW_LINK_BTN_CLASSES, "prev_object_link", disabled)
      type = object.type_tag

      icon_link_to(
        :PREV_OBJECT.t(type: :"#{type.upcase}".l),
        add_query_param(
          send(show_link_path(type), object.id, flow: "prev"), query
        ),
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
        add_query_param(
          send(show_link_path(type), object.id, flow: "next"), query
        ),
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

    def show_link_index(object, query)
      classes = class_names(SHOW_LINK_BTN_CLASSES, %w[mx-1 index_object_link])
      icon = show_link_index_icon(object)
      type = object.type_tag.to_s.pluralize

      icon_link_to(
        :INDEX_OBJECT.t(type: :"#{type.upcase}".l),
        add_query_param(object.index_link_args, query),
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
