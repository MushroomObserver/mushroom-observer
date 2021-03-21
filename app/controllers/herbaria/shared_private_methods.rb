# frozen_string_literal: true

# private methods shared by HerbariaController and subcontrollers
module Herbaria::SharedPrivateMethods
  private

  # ---------- Filters ---------------------------------------------------------

  def keep_track_of_referrer
    @back = params[:back] || request.referer
  end

  def redirect_to_referrer
    return false if @back.blank?

    redirect_to(@back)
    true
  end

  # ---------- Indices ---------------------------------------------------------

  def show_selected_herbaria(query, args = {})
    args = show_index_args(args)

    # Clean up display by removing user-related stuff from nonpersonal index.
    if query.flavor == :nonpersonal
      args[:sorting_links].reject! { |x| x[0] == "user" }
      @no_user_column = true
    end

    # If user clicks "merge" on an herbarium, it reloads the page and asks
    # them to click on the destination herbarium to merge it with.
    @merge = Herbarium.safe_find(params[:merge])
    @links = right_tab_links(query, @links)
    show_index_of_objects(query, args)
  end

  def show_index_args(args)
    { # default args
      letters: "herbaria.name",
      num_per_page: 100,
      include: [:curators, :herbarium_records, :personal_user]
    }.merge(args,
            template: "/herbaria/index.html.erb", # render with this template
            sorting_links: [ # Add some alternate sorting criteria.
              ["records",     :sort_by_records.t],
              ["user",        :sort_by_user.t],
              ["code",        :sort_by_code.t],
              ["name",        :sort_by_name.t],
              ["created_at",  :sort_by_created_at.t],
              ["updated_at",  :sort_by_updated_at.t]
            ])
  end

  def right_tab_links(query, links)
    links ||= []
    unless query.flavor == :all
      links << [:herbarium_index_list_all_herbaria.l,
                herbaria_path(flavor: :all)]
    end
    unless query.flavor == :nonpersonal
      links << [:herbarium_index_nonpersonal_herbaria.l,
                herbaria_path(flavor: :nonpersonal)]
    end
    links << [:create_herbarium.l, new_herbarium_path]
  end

  # ---------- Merges ----------------------------------------------------------

  # Used by create, edit and HerbariaMerges

  def perform_or_request_merge(this, that)
    if in_admin_mode? || this.can_merge_into?(that)
      perform_merge(this, that)
    else
      request_merge(this, that)
    end
  end

  def perform_merge(this, that)
    old_name = this.name_was
    result = this.merge(that)
    flash_notice(
      :runtime_merge_success.t(
        type: :herbarium, this: old_name, that: result.name
      )
    )
    result
  end

  def request_merge(this, that)
    redirect_with_query(
      observer_email_merge_request_path(
        type: :Herbarium, old_id: this.id, new_id: that.id
      )
    )
    false
  end
end
