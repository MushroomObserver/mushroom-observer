# frozen_string_literal: true

# Prev/Index/Next navigation for show pages. Stashed in
# `content_for(:prev_next_object)` by
# `Header::ShowPrevNextHelper#add_pager_for`. Renders nothing when
# either prop is nil — the helper already gates on the same.
module Views::Layouts
  class Header::ShowPrevNextNav < Views::Base
    BTN_CLASSES = (Components::Navbar::LINK_CLASSES + %w[navbar-left]).freeze

    prop :object, _Nilable(::AbstractModel), default: nil
    prop :query, _Nilable(::Query), default: nil

    def view_template
      return unless @object && @query

      ul(class: "nav navbar-flex object_pager") do
        li { render_adjacent_link(:prev) }
        li { render_index_link }
        li { render_adjacent_link(:next) }
      end
    end

    private

    def render_adjacent_link(dir)
      hide = no_more?(dir) ? "disabled opacity-0" : ""
      classes = class_names(BTN_CLASSES, "#{dir}_object_link", hide)
      adjacent_id = @query.send(:"#{dir}_id")
      href = adjacent_id ? adjacent_path(adjacent_id) : "#"

      Link(type: :icon, content: adjacent_title(dir), path: href,
           icon: dir, class: classes)
    end

    def render_index_link
      classes = class_names(BTN_CLASSES, %w[mx-1 index_object_link])

      Link(type: :icon, content: index_title, path: index_path,
           icon: index_icon, class: classes)
    end

    def no_more?(dir)
      if dir == :prev
        @query.result_ids.first == @object.id
      else
        @query.result_ids.last == @object.id
      end
    end

    def adjacent_path(id)
      return activity_log_path(id: id) if type_tag == :rss_log

      send(:"#{type_tag}_path", id: id)
    end

    def adjacent_title(dir)
      :"#{dir.upcase}_OBJECT".t(type: type_name)
    end

    def index_path
      args = add_q_param(@object.index_link_args, @query)
      url_for(args.merge(only_path: true))
    end

    def index_title
      :INDEX_OBJECT.t(type: type_name.pluralize)
    end

    def index_icon
      type_tag == :observation ? :grid : :list
    end

    def type_tag
      @type_tag ||= @object.type_tag
    end

    def type_name
      @type_name ||= :"#{type_tag.upcase}".l
    end
  end
end
