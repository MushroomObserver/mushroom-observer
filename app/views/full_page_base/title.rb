# frozen_string_literal: true

# Page-title methods mixed into `Views::FullPageBase`.
#
# Each setter writes to `content_for(:title)` (visible page heading,
# HTML-safe), `content_for(:document_title)` (browser-tab `<title>`,
# plain text), or — for index titles — `content_for(:filters)` for
# the result-set caption. The layout reads these slots when it renders.
#
# `add_show_title` / `add_edit_title` / `add_query_filters` wrap their
# inner `render(...)` calls in `capture` because Phlex 2.x's `render`
# emits to the buffer rather than returning a string; the slot needs
# the HTML as a string to stash and later read with `trusted_html`.
module Views::FullPageBase::Title
  # Most generic: caller supplies the heading + (optionally) a separate
  # plain-text doc title. Show / edit / new / index versions below all
  # ultimately route through this method.
  def add_page_title(title, document_title = title)
    content_for(:title) { title }
    content_for(:document_title) { title_tag_contents(document_title) }
  end

  # Show-mode object title: the rich heading is the
  # `Views::Layouts::Header::ObjectTitle` view (with the user's naming
  # prefs applied); the doc title is the model's plain `document_title`
  # (or its type-tag label) prefixed with `Type id:`. Pass
  # `owner_naming: true` on an observation's show page to add the
  # observer's-preferred-naming line under the title (nothing renders
  # if the viewer hasn't opted in or the owner agrees with consensus).
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

  # Edit-mode object title: heading flips to `mode: :edit`; doc title
  # gets a leading `EDIT` label.
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

  # `label_key`'s template reads "Verb words [name]" or
  # "Verb words [object]" (e.g. :ask_observation_question_title,
  # :move_descriptions_title) -- pass whichever placeholder the
  # template uses as `name:` or `object:`. Puts the name, with a
  # leading id badge, on a line apart from the label and any trailing
  # text -- see `title_with_name` below for why. Returns the HTML
  # rather than installing it, so a caller needing different wrapping
  # can feed it to `add_page_title` itself; `add_title_with_name`
  # below is the common case.
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

  # Index pages: the page heading is empty (the top nav's rubric
  # already shows the model name); the doc title is the model name;
  # the result-set caption explains any filters.
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

  # Index-only caption explaining what filters the current Query
  # applies. The caption HTML is built by
  # `Views::Layouts::Header::IndexBar::FilterCaption`. Skips the wrap
  # when there's no query, or the query has no filters to caption --
  # an unfiltered index has nothing worth a caption row for.
  def add_query_filters(query)
    klass = ::Views::Layouts::Header::IndexBar::FilterCaption
    return unless query&.params && klass.filters_present?(query)

    content_for(:filters) do
      capture { render(klass.new(query: query)) }
    end
  end

  private

  # Splits the localized but uninterpolated template on its
  # placeholder, rather than hunting for HTML tags in the rendered
  # title, so the split lands correctly regardless of what markup the
  # name renders as -- and regardless of word order: some locales
  # (ja, zh, ru) put the placeholder before the label text, or embed
  # trailing text after it, rather than trailing the label. Label,
  # name, and trailing text each get a separate block, so none of
  # them shares a line with the name, whichever locale puts what
  # where.
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

  # `title-name-line`'s padding-left (not .hanging-indent) indents
  # every line this wraps to, the first included -- no shared-line
  # label text is left for only the continuation lines to align
  # under. The name, and its leading space, are one flex item, not
  # several -- flexbox collapses whitespace between sibling flex
  # items, which otherwise eats the space before "group" and glues
  # the badge's digits onto the name in plain-text extraction.
  def render_name_line(object, user)
    render(::Components::IDBadge.new(object: object, size: :sm))
    span do
      whitespace
      trusted_html(viewer_aware_format_name(object, user).t.small_author)
    end
  end

  # Wide/full containers have room for the label and name on one
  # line -- plain interpolated title, no id badge, no line splits.
  def inline_title_with_name(label_key, object, placeholder, user)
    label_key.t(placeholder.to_sym => viewer_aware_format_name(object, user)).
      small_author
  end

  # The id-badge/line-split treatment only reads well in a narrow
  # container: :text column -- a wide/full container has room for
  # the label and name on one line. `container_class` may not have
  # been called yet when this runs (most actions rely on its :text
  # default), so unset means :text, not "unknown".
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

  # `Header::PageTitle` places this HTML twice -- next to the object
  # name on desktop, and again in the mobile-only top row. No
  # `extra_class:` here -- each placement site supplies the spacing
  # that context needs. `size: :xl`: neither placement nests the
  # badge inside a heading anymore, so it can't ride on an ancestor's
  # font-size the way `:sm`/`:md`/`:lg` are meant to; `:xl` is the
  # one size in `Components::IDBadge::SIZE_CLASSES` not scaled down.
  def add_id_badge(object)
    content_for(:id_badge) do
      capture do
        render(::Components::IDBadge.new(object: object, size: :xl,
                                         extra_class: nil))
      end
    end
  end

  # Captured HTML for `add_show_title`'s `owner_naming:` line, or nil
  # when disabled or the line has nothing to show (the view decides
  # via `visible_for?`).
  def owner_naming_html(object, user, enabled)
    return nil unless enabled

    # Aliased to a local because the `LocalizationFilesTest` regex
    # picks up `:OwnerNamingLine` after a `::` namespace separator
    # and flags it as an undefined translation tag.
    klass = ::Views::Controllers::Observations::OwnerNamingLine
    return nil unless klass.visible_for?(observation: object, user: user)

    capture { render(klass.new(observation: object, user: user)) }
  end

  # Models with no `Title::` subclass (see app/classes/title.rb) fall
  # back to their localized type tag (`observation`, `location`, etc.).
  # The browser-tab text renders as plain text, so textile / HTML must
  # NOT leak through.
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

  # The actual content of `<title>` in `<head>`. Strips textile / HTML
  # tags + entities (the visible heading may be marked-up; the tab text
  # must be plain). Falls back to a titleized action name when nothing
  # was set.
  def title_tag_contents(title, action: action_name)
    if title.present?
      # `unescape_html` first so `&lt;i&gt;…&lt;/i&gt;` (entity-encoded
      # tags from translations) becomes `<i>…</i>` BEFORE `strip_html`
      # removes the tags. Doing it in the other order leaves escaped
      # entities untouched, then unescapes them into real tags after
      # the strip — which the layout's `trusted_html(content_for(
      # :document_title))` would then render literally.
      title.unescape_html.strip_html
    else
      action.tr("_", " ").titleize
    end
  end
end
