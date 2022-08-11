# frozen_string_literal: true

class Query::NameDescriptionByAuthor < Query::NameDescriptionBase
  def parameter_declarations
    super.merge(
      user: User,
      old_by?: :string
    )
  end

  def initialize_flavor
    user = find_cached_parameter_instance(User, :user)
    title_args[:user] = user.legal_name
    add_join(:name_description_authors)
    where << "name_description_authors.user_id = '#{user.id}'"
    super
  end

  def coerce_into_name_query
    Query.lookup(:Name, :with_descriptions_by_author, params_plus_old_by)
  end
end
