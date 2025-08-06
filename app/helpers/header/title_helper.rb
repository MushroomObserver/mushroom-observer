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
    def add_show_title(string, object)
      add_page_title(
        show_page_title(string, object), show_document_title(string, object)
      )
    end

    # The record title preceded by the id as a badge, as HTML
    # "[23435] Amanita novinupta"
    def show_page_title(string, object)
      [show_title_id_badge(object), string].safe_join(" ")
    end

    def show_title_id_badge(object)
      tag.span(object.id || "?", class: "badge badge-id mr-3")
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

    def add_edit_title(string, object)
      add_page_title(
        edit_page_title(string, object),
        edit_document_title(string, object)
      )
    end

    # Needs to be separate. Called in modal forms
    def edit_page_title(string, object)
      [:EDIT.l, show_page_title(string, object)].safe_join(" ")
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
        tag.h5(naming, id: "owner_naming")
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
