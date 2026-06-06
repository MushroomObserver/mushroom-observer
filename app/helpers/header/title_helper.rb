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
    def add_show_title(object, user: nil)
      add_page_title(
        show_page_title(page_title_for(object, user), object),
        show_document_title(document_title_for(object), object)
      )
    end

    # The record title preceded by the id as a badge, as HTML
    # "[23435] Amanita novinupta"
    def show_page_title(string, object)
      tag.div(class: "d-flex align-items-center") do
        [show_title_id_badge(object), tag.span(string)].safe_join(" ")
      end
    end

    # Look up the model's `page_title` (HTML/textile string) or fall
    # back to its localized type-tag label.
    #
    # Observation is special-cased: the obs show heading wraps the
    # consensus name in a link to the name page (with a "(Site ID)"
    # flag when the owner's preferred naming differs). That logic
    # lives in `observations_helper#observation_show_title` — view-
    # layer work we don't want to push onto the model. The title
    # helper has access to it via the helper chain.
    #
    # The arity check lets models alias `page_title` to a zero-arg
    # accessor (e.g. `alias page_title title`) instead of writing a
    # one-line wrapper that ignores the user — calling `title(user)`
    # would raise ArgumentError. `arity.zero?` is true when the
    # method takes no required args; we then call it with none.
    def page_title_for(object, user = nil)
      return observation_page_title(object, user) if object.is_a?(Observation)
      return fallback_title(object) unless object.respond_to?(:page_title)

      if object.method(:page_title).arity.zero?
        object.page_title
      else
        object.page_title(user)
      end
    end

    # Observation's page heading: link-wrapped consensus name plus
    # the optional "(Site ID)" flag computed from the owner's
    # preferred naming. The obs show view also independently uses
    # the owner-preferred-naming via `add_owner_naming` (separate
    # display); recomputing here is the cost of keeping the model
    # free of view code.
    def observation_page_title(obs, user)
      observation_show_title(
        obs: obs, user: user,
        show_owner_naming: owner_naming_line(
          name: obs.name,
          owner_name: ::Observation::NamingConsensus.new(obs).owner_preference,
          user: user
        )
      )
    end

    # Look up the model's `document_title` (plain-text string) or
    # fall back to its localized type-tag label. The `<title>` element
    # renders as plain text — textile / HTML must NOT leak through.
    def document_title_for(object)
      return fallback_title(object) unless object.respond_to?(:document_title)

      object.document_title
    end

    def fallback_title(object)
      :"#{object.type_tag.to_s.upcase}".l
    end

    # Kept for the one remaining ERB caller (`names/_name.erb`).
    # Phlex callers should `render(Components::IdBadge.new(...))`
    # directly instead.
    def show_title_id_badge(object, classes = "mr-4")
      render(Components::IdBadge.new(object: object,
                                     extra_class: classes))
    end

    # Div shows even without content to maintain layout
    def show_page_edit_icons
      classes = %w[
        nav d-flex align-items-center justify-content-end mt-0 h4 object_edit
      ]

      tag.ul(class: class_names(classes)) do
        content_for(:edit_icons)
      end
    end

    # Div shows even without content to maintain layout
    def show_page_interest_icons
      classes = %w[nav navbar-flex interest-eyes h4 my-0]

      tag.ul(class: class_names(classes)) do
        content_for(:interest_icons)
      end
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
        edit_page_title(page_title_for(object, user), object),
        edit_document_title(document_title_for(object), object)
      )
    end

    # Needs to be separate. Called in modal forms.
    # `html_str` is already the rendered HTML (textile applied by the
    # model's `page_title`) — we just compose it next to the
    # `:edit_object.t(type: …)` label.
    def edit_page_title(html_str, object)
      tag.div(class: "d-flex align-items-center") do
        [
          show_title_id_badge(object),
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
    # HTML tag is here so no empty header printed in case there is no naming
    def add_owner_naming(naming)
      return unless naming

      content_for(:owner_naming) do
        tag.h5(naming, class: "pl-3 mt-0 mb-4", id: "owner_naming")
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
