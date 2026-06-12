# frozen_string_literal: true

# Renders a Bootstrap 3 Glyphicon `<span>` with the MO `link-icon`
# class added. Optionally adds a tooltip + screen-reader title.
#
# Drop-in equivalent of the long-standing `link_icon(type, **args)`
# helper in `app/helpers/link_helper.rb`; the helper now renders this
# component so existing ERB and Phlex callers keep working unchanged.
#
# @example Just the glyph
#   render(Components::LinkIcon.new(type: :globe))
#   # => <span class="glyphicon glyphicon-globe link-icon"></span>
#
# @example With tooltip + screen-reader title + extra CSS
#   render(Components::LinkIcon.new(
#     type: :edit, title: :EDIT.l, html_class: "text-primary"
#   ))
#   # => <span class="glyphicon glyphicon-edit link-icon text-primary"
#   #          title="Edit" data-toggle="tooltip">
#   #      <span class="sr-only">Edit</span>
#   #    </span>
class Components::LinkIcon < Components::Base
  prop :type, _Nilable(Symbol), default: nil
  prop :title, _Nilable(String), default: nil
  prop :html_class, _Nilable(String), default: nil
  prop :data, Hash, default: -> { {} }
  prop :attributes, Hash, default: -> { {} }

  def view_template
    glyph = LinkHelper::LINK_ICON_INDEX[@type]
    return unless glyph

    span(class: span_class(glyph),
         title: @title.presence,
         data: span_data,
         **@attributes) do
      span(class: "sr-only") { plain(@title) } if @title.present?
    end
  end

  private

  def span_class(glyph)
    base = "glyphicon glyphicon-#{glyph} link-icon"
    @html_class ? "#{base} #{@html_class}" : base
  end

  def span_data
    @title.present? ? { toggle: "tooltip" }.merge(@data) : @data
  end
end
