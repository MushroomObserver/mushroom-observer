# frozen_string_literal: true

module Views::Controllers::Info
  # News page — static textile content.
  class News < Views::FullPageBase
    def view_template
      add_page_title(:news_title.l)

      trusted_html(:news_header.tp)
      trusted_html(:news_content.tp)
    end
  end
end
