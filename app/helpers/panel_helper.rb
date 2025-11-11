# frozen_string_literal: true

# helpers for bootstrap panels
module PanelHelper
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
  def help_note(element = :span, string = "", **args)
    args[:class] = class_names("help-note mr-3", args[:class])
    content_tag(element, string, args)
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
    div_class = "well well-sm mb-3 help-block position-relative"
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
    div_class = "well well-sm mb-3 help-block position-relative"
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

  # PLEASE KEEP, this is laborious to re-write if we ever need tabbed panes
  # # BOOTSTRAP TABBED CONTENT activated by JS
  # # not to be confused with MO "tabs", i.e. link definition POROs
  # #
  # # Bootstrap tablist
  # def tab_nav(**args, &block)
  #   if args[:tabs]
  #     content = capture do
  #       args[:tabs].each do |tab|
  #         concat(tab_item(tab[:name], id: tab[:id], active: tab[:active]))
  #       end
  #     end
  #   elsif block
  #     content = capture(&block).to_s
  #   else
  #     content = ""
  #   end
  #   style = args[:style] || "pills"

  #   tag.ul(
  #     role: "tablist",
  #     class: class_names("nav nav-#{style}", args[:class]),
  #     **args.except(:class, :style)
  #   ) do
  #     content
  #   end
  # end

  # # Bootstrap "tab" item in ul/li tablist
  # def tab_item(name, **args)
  #   active = args[:active] ? "active" : nil
  #   disabled = args[:disabled] ? "disabled" : nil

  #   tag.li(
  #     role: "presentation",
  #     class: class_names(active, disabled, args[:class])
  #   ) do
  #     tab_toggle(name, **args.except(:active, :disabled, :class))
  #   end
  # end

  # # Bootstrap tab - just the link that switches tabs.
  # # Use for independent tab (e.g. button).
  # def tab_toggle(name, **args)
  #   classes = args[:button] ? "btn btn-default" : "nav-link"

  #   link_to(
  #     name, "##{args[:id]}-tab-pane",
  #     role: "tab", id: "#{args[:id]}-tab", class: classes,
  #     data: { toggle: "tab" }, aria: { controls: "#{args[:id]}-tab-pane" }
  #   )
  # end

  # # Bootstrap tabpanel wrapper
  # def tab_content(**args, &block)
  #   content = capture(&block).to_s

  #   tag.div(class: class_names("tab-content", args[:class]),
  #           **args.except(:class)) do
  #     content
  #   end
  # end

  # # Bootstrap tabpanel
  # def tab_panel(**args, &block)
  #   content = capture(&block).to_s
  #   active = args[:active] ? "in active" : nil

  #   tag.div(
  #     role: "tabpanel", id: "#{args[:id]}-tab-pane",
  #     class: class_names("tab-pane fade", active, args[:class]),
  #     aria: { labelledby: "#{args[:id]}-tab" },
  #     **args.except(:class, :id)
  #   ) do
  #     content
  #   end
  # end
end
