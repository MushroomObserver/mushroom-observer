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
  # (or its type-tag label) prefixed with `Type id:`.
  def add_show_title(object, user: nil)
    add_page_title(
      capture do
        render(::Views::Layouts::Header::ObjectTitle.new(
                 object: object, user: user
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
                locations: query.model.table_name.upcase.to_sym.l
              )
            elsif query
              query.model.table_name.upcase.to_sym.l
            else
              ""
            end
    add_page_title(title)
    add_query_filters(query)
  end

  # Show-obs only: the observer's preferred naming sits on a second
  # title line. The line view decides whether to render via its own
  # `visible_for?` predicate — skip the wrap when nothing would render
  # so we don't emit an empty `<h5>`.
  def add_owner_naming(observation:, user:)
    # Aliased to a local because the `LocalizationFilesTest` regex
    # picks up `:OwnerNamingLine` after a `::` namespace separator
    # and flags it as an undefined translation tag.
    klass = ::Views::Controllers::Observations::OwnerNamingLine
    return unless klass.visible_for?(observation: observation,
                                     user: user)

    content_for(:owner_naming) do
      capture do
        h5(class: "pl-3 mt-0 mb-4", id: "owner_naming") do
          render(klass.new(observation: observation, user: user))
        end
      end
    end
  end

  # Index-only caption explaining what filters the current Query
  # applies. The caption HTML is built by
  # `Views::Layouts::Header::IndexBar::FilterCaption`. Skips the wrap
  # when there's no query to caption.
  def add_query_filters(query)
    return unless query&.params

    content_for(:filters) do
      capture do
        render(::Views::Layouts::Header::IndexBar::FilterCaption.new(
                 query: query
               ))
      end
    end
  end

  private

  # Models without `document_title` fall back to their localized type
  # tag (`OBSERVATION`, `LOCATION`, etc.). The browser-tab text renders
  # as plain text, so textile / HTML must NOT leak through.
  def document_title_for(object)
    return :"#{object.type_tag.to_s.upcase}".l \
      unless object.respond_to?(:document_title)

    object.document_title
  end

  # `Observation 23435: Amanita novinupta`
  def show_document_title(string, object)
    [
      :"#{object.type_tag.to_s.upcase}".l,
      "#{object.id}:",
      string
    ].safe_join(" ")
  end

  def edit_document_title(string, object)
    [:EDIT.l, show_document_title(string, object)].safe_join(" ")
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
