# frozen_string_literal: true

# see app/controllers/names_controller.rb
class NamesController

  ##############################################################################
  #
  #  :section: Indexes and Searches
  #
  ##############################################################################

  # Display list of names in last index/search query.
  def index_name
    query = find_or_create_query(
      :Name,
      by: params[:by]
    )
    show_selected_names(query, id: params[:id].to_s, always_index: true)
  end

  # Display list of all (correctly-spelled) names in the database.
  def index
    query = create_query(
      :Name,
      :all,
      by: :name
    )
    show_selected_names(query)
  end

  alias_method :list_names, :index

  # Display list of names that have observations.
  def observation_index
    query = create_query(
      :Name,
      :with_observations
    )
    show_selected_names(query)
  end

  # Display list of names that have authors.
  def authored_names
    query = create_query(
      :Name,
      :with_descriptions
    )
    show_selected_names(query)
  end

  # Display list of names that a given user is author on.
  def names_by_user
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(
      :Name,
      :by_user,
      user: user
    )
    show_selected_names(query)
  end

  # This no longer makes sense, but is being requested by robots.
  alias names_by_author names_by_user

  # Display list of names that a given user is editor on.
  def names_by_editor
    user = params[:id] ? find_or_goto_index(User, params[:id].to_s) : @user
    return unless user

    query = create_query(
      :Name,
      :by_editor,
      user: user
    )
    show_selected_names(query)
  end

  # Display list of the most popular 100 names that don't have descriptions.
  def needed_descriptions
    # NOTE!! -- all this extra info and help will be lost if user re-sorts.
    data = Name.connection.select_rows %(
      SELECT names.id, name_counts.count
      FROM names LEFT OUTER JOIN name_descriptions
        ON names.id = name_descriptions.name_id,
           (SELECT count(*) AS count, name_id
            FROM observations group by name_id) AS name_counts
      WHERE names.id = name_counts.name_id
        # include "to_i" to avoid Brakeman "SQL injection" false positive.
        # (Brakeman does not know that Name.ranks[:xxx] is an enum.)
        AND names.rank = #{Name.ranks[:Species].to_i}
        AND name_counts.count > 1
        AND name_descriptions.name_id IS NULL
        AND CURRENT_TIMESTAMP - names.updated_at > #{1.week.to_i}
      ORDER BY name_counts.count DESC, names.sort_name ASC
      LIMIT 100
    )
    @help = :needed_descriptions_help
    query = create_query(
      :Name,
      :in_set,
      ids: data.map(&:first),
      title: :needed_descriptions_title.l
    )
    show_selected_names(query, num_per_page: 100)
  end

  # Display list of names that match a string.
  def name_search
    pattern = params[:pattern].to_s
    if pattern.match(/^\d+$/) &&
       (@name = Name.safe_find(pattern))
      # redirect_to(
      #   action: :show,
      #   id: @name.id
      # )
      redirect_to name_path(@name.id)
    else
      search = PatternSearch::Name.new(pattern)
      if search.errors.any?
        search.errors.each do |error|
          flash_error(error.to_s)
        end
        render action: :index
      else
        @suggest_alternate_spellings = search.query.params[:pattern]
        show_selected_names(search.query)
      end
    end
  end

  # Displays list of advanced search results.
  def advanced_search
    query = find_query(:Name)
    show_selected_names(query)
  rescue StandardError => e
    flash_error(e.to_s) if e.present?
    # redirect_to controller: :search, action: :advanced_search_form
    redirect_to search_advanced_search_form_path
  end

  # Used to test pagination.
  def test_index
    query = find_query(:Name)
    raise("Missing query: #{params[:q]}") unless query

    if params[:test_anchor]
      @test_pagination_args = { anchor: params[:test_anchor] }
    end
    show_selected_names(query, num_per_page: params[:num_per_page].to_i)
  end

  # Show selected search results as a list with 'list_names' template.
  def show_selected_names(query, args = {})
    store_query_in_session(query)
    @links ||= []
    args = {
      action: :index,
      letters: "names.sort_name",
      num_per_page: (/^[a-z]/i.match?(params[:letter].to_s) ? 500 : 50)
    }.merge(args)

    # Tired of not having an easy link to list_names.
    if query.flavor == :with_observations
      @links << [:all_objects.t(type: :name), { action: :index }]
    end

    # Add some alternate sorting criteria.
    args[:sorting_links] = [
      ["name", :sort_by_name.t],
      ["created_at", :sort_by_created_at.t],
      [(query.flavor == :by_rss_log ? "rss_log" : "updated_at"),
       :sort_by_updated_at.t],
      ["num_views", :sort_by_num_views.t]
    ]

    # Add "show observations" link if this query can be coerced into an
    # observation query.
    # @links << coerced_query_link(query, Observation)
    # NIMMO: Haven't figured out how to get coerced_query_link
    # (from application_controller) to work with paths. Building link here.
    if query&.coercable?(:Observation)
      @links << [link_to :show_objects.t(type: :observation),
                  observations_index_observation_path(:q => get_query_param)]

    # Add "show descriptions" link if this query can be coerced into a
    # description query.
    if query.coercable?(:NameDescription)
      # @links << [:show_objects.t(type: :description),
      #            add_query_param({ action: :index_name_description },
      #                            query)]
      @links << [
        link_to :show_objects.t(type: :description),
          name_descriptions_index_name_description_path(:q => get_query_param)
        ]
    end

    # Add some extra fields to the index for authored_names.
    if query.flavor == :with_descriptions
      show_index_of_objects(query, args) do |name|
        if (desc = name.description)
          [desc.authors.map(&:login).join(", "),
           desc.note_status.map(&:to_s).join("/"),
           :"review_#{desc.review_status}".t]
        else
          []
        end
      end
    else
      # Note: if show_selected_name is called with a block
      # it will *not* get passed to show_index_of_objects.
      show_index_of_objects(query, args)
    end
  end

end
