# frozen_string_literal: true

# The header block immediately below the application top nav. Rendered
# once per page by `Views::Layouts::Application#render_header_and_main`,
# inside the `content_for(:container_class)` width cap it shares with
# `#content`. On non-index actions, renders the page title strip
# (`Header::PageTitle`).
#
# The project banner (`:project_banner` content_for slot) renders
# separately, in `Views::Layouts::Application#render_nav_chrome`,
# ahead of the flash row -- a project's banner image/tabs always
# span the full page width.
#
# The index filter/pager bar (`Header::IndexBar`) and the rss-log
# type-filter row no longer render here -- `Header::IndexBar` moved
# to `Views::Layouts::Application` (above `:page_flash`, after
# `TopNav`), and the type-filter row renders inline with the pager
# via `IndexPaginationNav`'s `:type_filters` slot (see
# `Views::FullPageBase::IndexNav#add_type_filters`).
module Views::Layouts
  class Header < Views::Base
    def view_template
      header(id: "header") do
        render(PageTitle.new) if controller.action_name != "index"
      end
    end
  end
end
