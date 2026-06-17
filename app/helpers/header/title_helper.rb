# frozen_string_literal: true

# --------- Contextual Page Title -----------------------------
#
#  add_page_title(title)        # add content_for(:title)
#                                 and content_for(:document_title)
#  add_owner_naming(naming)     # add content_for(:owner_naming), on show obs
#  title_tag_contents           # text to put in html header <title>
#  add_index_title              # logic for index titles, with fallbacks
#  index_default_title          # logic for observations index default sort
#  add_query_filters(query)     # content_for(:filters)
#                                 builds filter caption explaining
#                                 index results, if filtered
#
module Header
  module TitleHelper
    # Per-model `page_title(user)` returns the rich/textile string
    # shown in the visible page heading; `document_title` returns the
    # plain string for the browser tab `<title>`. The doc title
    # renders as plain text, so we keep textile/HTML out of it. Models
    # without those methods fall back to a localized type-tag label.
    #
    # `user:` lets the page heading apply user-specific naming prefs
    # (e.g. hide_authors, deprecated-with-preferred-synonym link
    # wrapping). Document title ignores user — the tab text shouldn't
    # vary by viewer.
    #
    # The visible HTML side is built by
    # `Views::Layouts::Header::ObjectTitle` (`:show` mode here, `:edit`
    # in `add_edit_title`).
    def add_show_title(object, user: nil)
      add_page_title(
        render(::Views::Layouts::Header::ObjectTitle.new(
                 object: object, user: user
               )),
        show_document_title(document_title_for(object), object)
      )
    end

    # Look up the model's `document_title` (plain-text string) or
    # fall back to its localized type-tag label. The `<title>` element
    # renders as plain text — textile / HTML must NOT leak through.
    def document_title_for(object)
      return :"#{object.type_tag.to_s.upcase}".l \
        unless object.respond_to?(:document_title)

      object.document_title
    end

    # The record title as a string, preceded by the object type and id:
    # "Observation 23435: Amanita novinupta"
    def show_document_title(string, object)
      [
        :"#{object.type_tag.to_s.upcase}".l,
        "#{object.id}:",
        string
      ].safe_join(" ")
    end

    def add_edit_title(object, user: nil)
      add_page_title(
        render(::Views::Layouts::Header::ObjectTitle.new(
                 object: object, user: user, mode: :edit
               )),
        edit_document_title(document_title_for(object), object)
      )
    end

    # Modal-form edit title with a precomputed `html_str` (the modal
    # callers supply a type-tag label, not the model's `page_title`).
    # `add_edit_title` uses `Views::Layouts::Header::ObjectTitle` for
    # the model-driven version of the same flex+badge layout.
    def edit_page_title(html_str, object)
      tag.div(class: "d-flex align-items-center") do
        [
          render(::Components::IdBadge.new(object: object,
                                           extra_class: "mr-4")),
          tag.span do
            [:edit_object.t(type: object.type_tag),
             html_str].safe_join(": ")
          end
        ].safe_join(" ")
      end
    end

    def edit_document_title(string, object)
      [:EDIT.l, show_document_title(string, object)].safe_join(" ")
    end

    # Translation string taking a type_tag, e.g. :add_object, :create_object
    def add_new_title(string, type_tag)
      add_page_title(new_page_title(string, type_tag))
    end

    # Needs to be separate. Called in modal forms.
    def new_page_title(string, type_tag)
      :"#{string}".t(type: type_tag)
    end

    # NOTE: When it's a show page for an ActiveRecord object, an
    # edit form or a new form page, please use the helpers
    # `add_show_title`, `add_edit_title` or `add_new_title` above.
    # These allow standardization of the record "ID" badge UI.
    #
    # NOTE: Sets both the html doc <title> and the #title for the page,
    # but they are a bit different and can be explicitly set differently.
    def add_page_title(title, document_title = title)
      content_for(:title) do
        title
      end
      content_for(:document_title) do
        title_tag_contents(document_title)
      end
    end

    # Show obs: observer's preferred naming.
    # HTML tag is here so no empty header printed when the line
    # shouldn't be shown. Takes the observation and viewer
    # directly — `Views::Controllers::Observations::OwnerNamingLine`
    # decides whether to render anything via its `visible_for?`
    # predicate — checked here BEFORE rendering so a blank h5
    # isn't emitted when the view ends up empty.
    def add_owner_naming(observation:, user:)
      # Aliased to a local because the `LocalizationFilesTest`
      # regex picks up `:OwnerNamingLine` after a `::` namespace
      # separator and flags it as an undefined translation tag.
      klass = ::Views::Controllers::Observations::OwnerNamingLine
      return unless klass.visible_for?(observation: observation,
                                       user: user)

      line = render(klass.new(observation: observation, user: user))
      content_for(:owner_naming) do
        tag.h5(line, class: "pl-3 mt-0 mb-4", id: "owner_naming")
      end
    end

    # contents of the <title> in html <head>
    def title_tag_contents(title, action: controller.action_name)
      if title.present?
        title.strip_html.unescape_html # removes tags and special chars
      else
        action.tr("_", " ").titleize
      end
    end

    # Simple builder for index page titles, shown only in the <title>.
    # The top_nav `rubric` contains what was formerly the index title, i.e.
    # the model name pluralized.
    # Also sets the "filter caption" that explains the query, shown on the page
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
  end
end
