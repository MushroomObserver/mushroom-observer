# frozen_string_literal: true

module Views::Controllers::Admin::Donations
  # Review-donations page. Delegates the body to `DonationsTable`;
  # this wrapper sets the page chrome (full-width container, title,
  # context nav).
  class Edit < Views::FullPageBase
    prop :donations, _Array(::Donation)
    prop :query, ::Query
    prop :pagination_data, ::PaginationData

    def view_template
      container_class(:full)
      content_padding(:panels)
      add_page_title(:review_donations_title.l)
      add_context_nav(::Tab::Admin::DonationsFormEdit.new)
      add_sorter(@query, controller.index_sort_options)
      add_pagination(@pagination_data)

      PaginatedResults do
        render(DonationsTable.new(donations: @donations))
      end
    end
  end
end
