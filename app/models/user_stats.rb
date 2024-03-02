# frozen_string_literal: true

# Keep track of each user's contributions

#  == Attributes
#
#  user_id::                User.
#
#  == Counts of records the user has created:
#
#  comments::
#  images::
#  location_description_authors::
#  location_description_editors::
#  locations::
#  locations_versions::
#  name_description_authors::
#  name_description_editors::
#  names::
#  names_versions::
#  namings::
#  observations::
#  sequences::
#  sequenced_observations::
#  species_list_entries::
#  species_lists::
#  translation_strings_versions::
#  votes::
#
#  == Counts of translation_strings_versions per language:
#
#  ar::
#  be::
#  de::
#  el::
#  es::
#  fa::
#  fr::
#  it::
#  jp::
#  pl::
#  pt::
#  ru::
#  tr::
#  uk::
#  zh::

class UserStats < AbstractModel
  belongs_to :user
end
