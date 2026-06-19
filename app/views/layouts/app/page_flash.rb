# frozen_string_literal: true

module Views::Layouts::App
  # The `#page_flash` container that the JS layer can target to
  # inject new flash messages. Always rendered (even when empty)
  # so JS has a stable mount point.
  class PageFlash < Views::Base
    def view_template
      div(class: "container-full hidden-print", id: "page_flash") do
        render(FlashNotices.new)
      end
    end
  end
end
