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
