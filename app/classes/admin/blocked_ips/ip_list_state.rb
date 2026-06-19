# frozen_string_literal: true

module Admin
  module BlockedIps
    # Immutable state for one paginated, prefix-filtered IP list
    # (either okay or blocked). Bundles the 5 fields the
    # `Admin::BlockedIps::Edit` view + `Manager` form component
    # consume — avoids 5 parallel ivars per list on the controller.
    #
    #   IpListState[
    #     ips: %w[1.2.3.4 ...],   # current page's IPs
    #     page: 1,                # current page (1-based)
    #     total_pages: 3,
    #     total_count: 137,
    #     starts_with: "10."      # active prefix filter, or nil
    #   ]
    IpListState = Data.define(
      :ips, :page, :total_pages, :total_count, :starts_with
    )
  end
end
