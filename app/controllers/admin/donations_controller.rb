# frozen_string_literal: true

module Admin
  # Allow users to make monetary donations via the website
  class DonationsController < AdminController
    def new
      @donation = Donation.new
      render(Views::Controllers::Admin::Donations::New.new(donation: @donation))
    end

    def create
      @donation = create_donation(params)
      flash_notice(:create_donation_success.t)
      # A same-URL non-redirect response on a Turbo-enabled form hangs
      # Turbo Drive (see turbo_submit_forms.md); redirect back to the
      # form instead of implicitly rendering a blank 204.
      redirect_to(new_admin_donations_path)
    end

    # Review donations
    def edit
      # Sort links submit a q[...] param, not ?by=X, so the query has
      # to be looked up (find_or_create_query), not rebuilt from
      # scratch (create_query would drop the requested sort).
      @query = find_or_create_query(:Donation,
                                    order_by: order_by_or_flash_if_unknown)
      update_stored_query(@query)
      @pagination_data = PaginationData.new(
        number_arg: :page,
        number: params[:page],
        num_per_page: calc_layout_params["count"]
      )
      @donations = @query.paginate(@pagination_data)
      render(Views::Controllers::Admin::Donations::Edit.new(
               donations: @donations, query: @query,
               pagination_data: @pagination_data
             ))
    end

    # Sort options for the review-donations page. Read by `add_sorter`
    # in the view.
    def index_sort_options
      [
        ["created_at", :sort_by_created_at.t],
        ["amount", :sort_by_amount.t],
        ["who", :sort_by_who.t]
      ].freeze
    end

    # Submitted by a single row's ReviewToggle on checkbox change --
    # params[:reviewed] has one id => value entry.
    def update
      update_donations(params[:reviewed])
      respond_to do |format|
        format.turbo_stream { render_reviewed_toggle_stream }
        format.html do
          flash_notice(:review_donations_success.t)
          # A same-URL 200 render on a Turbo-enabled form hangs Turbo
          # Drive (see turbo_submit_forms.md) -- redirect instead of
          # re-rendering.
          redirect_to(edit_admin_donations_path)
        end
      end
    end

    private

    def render_reviewed_toggle_stream
      donation = Donation.find(params[:reviewed].keys.first)
      render(turbo_stream: turbo_stream.replace(
        "donation_reviewed_#{donation.id}",
        Views::Controllers::Admin::Donations::ReviewToggle.new(
          donation: donation
        )
      ))
    end

    def create_donation(params)
      email = params["donation"]["email"]
      Donation.create(amount: params["donation"]["amount"],
                      who: params["donation"]["who"],
                      recurring: params["donation"]["recurring"],
                      anonymous: params["donation"]["anonymous"],
                      email: email,
                      user: find_user(email),
                      reviewed: true)
    end

    def find_user(email)
      users = User.where(email: email)
      return unless users.length == 1

      users[0]
    end

    def update_donations(params)
      params.each do |x, y|
        d = Donation.find(x)
        d.reviewed = y
        d.save
      end
    end
  end
end
