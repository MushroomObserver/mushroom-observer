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
    # sets both the html doc title and
    # the title for the page (previously @title)
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
