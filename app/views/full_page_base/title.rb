# frozen_string_literal: true

# Page-title methods mixed into `Views::FullPageBase`. Setters write
# to content_for(:title)/(:document_title)/(:filters), read by the
# layout on render. `capture` wraps inner `render` calls since
# Phlex's `render` writes to the buffer, not a return value.
module Views::FullPageBase::Title
  # Every other add_*_title method routes through this one.
  def add_page_title(title, document_title = title)
    content_for(:title) { title }
    content_for(:document_title) { title_tag_contents(document_title) }
  end

  # owner_naming: true adds the observer's-preferred-naming line;
  # renders nothing if the viewer opted out or agrees with consensus.
  def add_show_title(object, user: nil, owner_naming: false)
    add_id_badge(object)
    add_page_title(
      capture do
        render(::Views::Layouts::Header::ObjectTitle.new(
                 object: object, user: user,
                 owner_naming: owner_naming_html(object, user, owner_naming)
               ))
      end,
      show_document_title(document_title_for(object), object)
    )
  end

  # Heading flips to mode: :edit; doc title gets a leading EDIT label.
  def add_edit_title(object, user: nil)
    add_id_badge(object)
    add_page_title(
      capture do
        render(::Views::Layouts::Header::ObjectTitle.new(
                 object: object, user: user, mode: :edit
               ))
      end,
      edit_document_title(document_title_for(object), object)
    )
  end

  # `string` is a translation key like `:add_object` / `:create_object`
  # that takes a `type:` interpolation.
  def add_new_title(string, type_tag)
    add_page_title(:"#{string}".t(type: type_tag))
  end

  # Pass whichever placeholder label_key's template uses, name: or
  # object:. Returns HTML rather than installing it, for a caller
  # needing different wrapping.
  def render_title_with_name(label_key, object: nil, name: nil,
                             user: default_viewer)
    target, placeholder = title_with_name_target(object, name)
    capture { title_with_name(label_key, target, placeholder, user) }
  end

  def add_title_with_name(label_key, object: nil, name: nil,
                          user: default_viewer)
    add_page_title(
      render_title_with_name(label_key, object: object, name: name,
                                        user: user)
    )
  end

  # Heading stays empty -- the top nav's rubric already names the model.
  def add_index_title(query, map: false)
    title = if map
              :map_locations_title.l(
                locations: query.model.table_name.to_sym.ti
              )
            elsif query
              query.model.table_name.to_sym.ti
            else
              ""
            end
    add_page_title(title)
    add_query_filters(query)
  end

  # Skips the wrap when there's no query or nothing to caption.
  def add_query_filters(query)
    klass = ::Views::Layouts::Header::IndexBar::FilterCaption
    return unless query&.params && klass.filters_present?(query)

    content_for(:filters) do
      capture { render(klass.new(query: query)) }
    end
  end

  private

  # Splits the raw template, not the rendered title -- locale word
  # order (ja, zh, ru put the placeholder before the label) varies.
  def title_with_name(label_key, object, placeholder, user)
    return inline_title_with_name(label_key, object, placeholder, user) unless
      text_container?

    label, _, trailing = label_key.l.partition("[#{placeholder}]")
    div do
      div { trusted_html(label.t) } if label.present?
      div(class: "title-name-line") { render_name_line(object, user) }
      div { trusted_html(trailing.t) } if trailing.present?
    end
  end

  def render_name_line(object, user)
    render(::Components::Badge.new(variant: :id, object: object, size: :sm,
                                   class: "mr-3"))
    span do
      trusted_html(viewer_aware_format_name(object, user).t.small_author)
    end
  end

  def inline_title_with_name(label_key, object, placeholder, user)
    label_key.t(placeholder.to_sym => viewer_aware_format_name(object, user)).
      small_author
  end

  # container_class may not have been called yet -- unset means :text,
  # not "unknown".
  def text_container?
    return true unless content_for?(:container_class)

    content_for(:container_class) == Components::Container.class_for(:text)
  end

  # One of object:/name: is required, not both -- whichever is given
  # says which placeholder the title's template uses.
  def title_with_name_target(object, name)
    raise(ArgumentError.new("pass one of object: or name:, not both")) if
      object.nil? == name.nil?

    object ? [object, "object"] : [name, "name"]
  end

  # Rendered twice by Header::PageTitle (desktop + mobile row), each
  # placement supplying the spacing it needs.
  # size: :xl since neither placement scales off an ancestor heading.
  def add_id_badge(object)
    content_for(:id_badge) do
      capture do
        render(::Components::Badge.new(variant: :id, object: object,
                                       size: :xl))
      end
    end
  end

  # nil when disabled or OwnerNamingLine.visible_for? says no.
  def owner_naming_html(object, user, enabled)
    return nil unless enabled

    # Local var, not inline -- LocalizationFilesTest's regex flags
    # `::OwnerNamingLine` as an undefined translation tag otherwise.
    klass = ::Views::Controllers::Observations::OwnerNamingLine
    return nil unless klass.visible_for?(observation: object, user: user)

    capture { render(klass.new(observation: object, user: user)) }
  end

  # Plain text only -- no Title:: subclass falls back to the type tag.
  def document_title_for(object)
    Title.for(object).document_title
  end

  # `Observation 23435: Amanita novinupta`
  def show_document_title(string, object)
    [
      object.type_tag.ti,
      object.id.to_s.concat(":"),
      string
    ].safe_join(" ")
  end

  def edit_document_title(string, object)
    [:edit.ti, show_document_title(string, object)].safe_join(" ")
  end

  # Strips textile/HTML; falls back to the titleized action name.
  def title_tag_contents(title, action: action_name)
    if title.present?
      # unescape_html first, or entity-encoded tags survive strip_html
      # and render literally later.
      title.unescape_html.strip_html
    else
      action.tr("_", " ").titleize
    end
  end
end
