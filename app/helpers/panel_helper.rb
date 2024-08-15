# frozen_string_literal: true

# helpers for bootstrap panels
module PanelHelper
  # For a collapsing panel_block, pass an HTML id for args[:collapse] and
  # args[:collapse_show] to show it open by default.
  # Pass args[:panel_bodies] to create multiple panel bodies, or args[:content]
  # to pass preformatted content instead of building `panel-body` here.
  def panel_block(**args, &block)
    heading = panel_heading(args)
    footer = panel_footer(args)
    content = block ? capture(&block).to_s : ""

    tag.div(
      class: class_names("panel panel-default", args[:class]),
      **args.except(*panel_inner_args)
    ) do
      concat(heading)
      if args[:panel_bodies].present?
        concat(panel_bodies(args))
      elsif args[:formatted_content].present?
        concat(content)
      elsif args[:collapse].present?
        concat(panel_collapse_body(args, content))
      else
        concat(panel_body(args, content))
      end
      concat(footer)
    end
  end

  # Args passed to panel components that are not applied to the outer div.
  def panel_inner_args
    [:class, :inner_class, :inner_id, :heading, :heading_links, :panel_bodies,
     :collapse, :open, :footer].freeze
  end

  def panel_heading(args)
    return "" unless args[:heading]

    tag.div(class: "panel-heading") do
      tag.h4(class: "panel-title") do
        els = [args[:heading]]
        if args[:heading_links].present?
          els << tag.span(args[:heading_links], class: "float-right")
        elsif args[:collapse].present?
          els << tag.span(panel_collapse_trigger(args), class: "float-right")
        end
        els.safe_join
      end
    end
  end

  # The caret icon that toggles the panel collapse.
  # NOTE: args[:open] should be a boolean
  def panel_collapse_trigger(args)
    icon_link_to(
      :OPEN.l,
      "##{args[:collapse]}",
      icon: :chevron_down,
      active_icon: :chevron_up,
      active_content: :CLOSE.l,
      class: "panel-collapse-trigger",
      role: "button", data: { toggle: "collapse" },
      aria: { expanded: args[:open], controls: args }
    )
  end

  def panel_body(args, content)
    return "" if content.blank?

    tag.div(class: class_names("panel-body", args[:inner_class]),
            id: args[:inner_id]) do
      concat(content)
    end
  end

  # Some panels need multiple panel bodies.
  def panel_bodies(args)
    args[:panel_bodies].map do |body|
      panel_body(args, body)
    end.safe_join
  end

  def panel_collapse_body(args, content)
    open = args[:open] ? "in" : ""

    tag.div(class: class_names("panel-collapse collapse", open),
            id: args[:collapse]) do
      concat(panel_body(args, content))
    end
  end

  def panel_footer(args)
    if args[:footer]
      tag.div(class: "panel-footer") do
        args[:footer]
      end
    else
      ""
    end
  end

  def alert_block(level = :warning, string = "")
    content_tag(:div, string, class: "alert alert-#{level}")
  end

  # Create a div for notes.
  #
  #   <%= notes_panel(html) %>
  #
  #   <% notes_panel() do %>
  #     Render stuff in here.  Note lack of "=" in line above.
  #   <% end %>
  #
  def notes_panel(msg = nil, &block)
    msg = capture(&block) if block
    result = tag.div(msg, class: "panel-body")
    wrapper = tag.div(result, class: "panel panel-default dotted-border")
    if block
      concat(wrapper)
    else
      wrapper
    end
  end

  # Help tooltip, note, block.
  #
  # Help tooltip is a span with a title attribute. This has the effect of
  # giving it context help (mouse-over popup) in most modern browsers.
  #
  #   <%= help_tooltip(label, title: "Click here to do something.") %>
  #
  def help_tooltip(label, **args)
    args[:data] ||= {}
    tag.span(label, title: args[:title],
                    class: class_names("context-help", args[:class]),
                    data: { toggle: "tooltip" }.merge(args[:data]))
  end

  # make a help-note styled element, like a div, p, or span
  def help_note(element = :span, string = "")
    content_tag(element, string, class: "help-note mr-3")
  end

  # make a help-block styled element, like a div, p
  def help_block(element = :div, string = "", **args, &block)
    content = block ? capture(&block) : string
    html_options = {
      class: class_names("help-block", args[:class])
    }.deep_merge(args.except(:class))

    content_tag(element, html_options) { content }
  end

  # draw a help block with an arrow
  def help_block_with_arrow(direction = nil, **args, &block)
    div_class = "well well-sm help-block position-relative"
    div_class += " mt-3" if direction == "up"

    tag.div(class: div_class, id: args[:id]) do
      concat(capture(&block).to_s)
      if direction
        arrow_class = "arrow-#{direction}"
        arrow_class += " hidden-xs" unless args[:mobile]
        concat(tag.div("", class: arrow_class))
      end
    end
  end

  def collapse_help_block(direction = nil, string = nil, **args, &block)
    div_class = "well well-sm help-block position-relative"
    div_class += " mt-3" if direction == "up"
    content = block ? capture(&block) : string

    tag.div(class: "collapse", id: args[:id]) do
      tag.div(class: div_class) do
        concat(content)
        if direction
          arrow_class = "arrow-#{direction}"
          arrow_class += " hidden-xs" unless args[:mobile]
          concat(tag.div("", class: arrow_class))
        end
      end
    end
  end

  def collapse_info_trigger(id, **args)
    link_to(link_icon(:question), "##{id}",
            class: class_names("info-collapse-trigger", args[:class]),
            role: "button", data: { toggle: "collapse" },
            aria: { expanded: "false", controls: id })
  end

  # BOOTSTRAP TABBED CONTENT
  #
  # Bootstrap tablist
  def tab_nav(**args, &block)
    if args[:tabs]
      content = capture do
        args[:tabs].each do |tab|
          concat(tab_item(tab[:name], id: tab[:id], active: tab[:active]))
        end
      end
    elsif block
      content = capture(&block).to_s
    else
      content = ""
    end
    style = args[:style] || "pills"

    tag.ul(
      role: "tablist",
      class: class_names("nav nav-#{style}", args[:class]),
      **args.except(:class, :style)
    ) do
      content
    end
  end

  # Bootstrap "tab" item in ul/li tablist
  def tab_item(name, **args)
    active = args[:active] ? "active" : nil
    disabled = args[:disabled] ? "disabled" : nil

    tag.li(
      role: "presentation",
      class: class_names(active, disabled, args[:class])
    ) do
      tab_link(name, **args.except(:active, :disabled, :class))
    end
  end

  # Bootstrap tab - just the link. Use for independent tab (e.g. button).
  def tab_link(name, **args)
    classes = args[:button] ? "btn btn-default" : "nav-link"

    link_to(
      name, "##{args[:id]}-tab-pane",
      role: "tab", id: "#{args[:id]}-tab", class: classes,
      data: { toggle: "tab" }, aria: { controls: "#{args[:id]}-tab-pane" }
    )
  end

  # Bootstrap tabpanel wrapper
  def tab_content(**args, &block)
    content = capture(&block).to_s

    tag.div(class: class_names("tab-content", args[:class]),
            **args.except(:class)) do
      content
    end
  end

  # Bootstrap tabpanel
  def tab_panel(**args, &block)
    content = capture(&block).to_s
    active = args[:active] ? "in active" : nil

    tag.div(
      role: "tabpanel", id: "#{args[:id]}-tab-pane",
      class: class_names("tab-pane fade", active, args[:class]),
      aria: { labelledby: "#{args[:id]}-tab" },
      **args.except(:class, :id)
    ) do
      content
    end
  end
end
