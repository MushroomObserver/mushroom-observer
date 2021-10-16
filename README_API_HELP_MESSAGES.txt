POST api_key
  app:	string (identifier used to help user distinguish which api key belongs to which app)
  for_user:	user (user you are creating api key for)
  password:	string (password of the user you are creating an API key for)

GET comment
  content_has:	string (search within body)
  created_at:	time range
  id:	integer list
  summary_has:	string (search within summary)
  target:	object (limit=Location|Name|Observation|Project|SpeciesList, e.g. "observation #1234" or "name #5678")
  type:	enum list (limit=location|name|observation|project|species_list)
  updated_at:	time range
  user:	user list (creator)

POST comment
  content:	string
  summary:	string (limit=100 chars)
  target:	object (limit=Location|Name|Observation|Project|SpeciesList)

PATCH comment
 query params
  content_has:	string (search within body)
  created_at:	time range
  id:	integer list
  summary_has:	string (search within summary)
  target:	object (limit=Location|Name|Observation|Project|SpeciesList, e.g. "observation #1234" or "name #5678")
  type:	enum list (limit=location|name|observation|project|species_list)
  updated_at:	time range
  user:	user list (creator)
 update params
  set_content:	string
  set_summary:	string (limit=100 chars, not blank)

DELETE comment
  content_has:	string (search within body)
  created_at:	time range
  id:	integer list
  summary_has:	string (search within summary)
  target:	object (limit=Location|Name|Observation|Project|SpeciesList, e.g. "observation #1234" or "name #5678")
  type:	enum list (limit=location|name|observation|project|species_list)
  updated_at:	time range
  user:	user list (creator)

GET external_link
  created_at:	time range
  external_site:	external_site list
  id:	integer list
  observation:	observation list
  updated_at:	time range
  url:	string
  user:	user list (creator)

POST external_link
  external_site:	external_site
  observation:	observation
  url:	string

PATCH external_link
 query params
  created_at:	time range
  external_site:	external_site list
  id:	integer list
  observation:	observation list
  updated_at:	time range
  url:	string
  user:	user list (creator)
 update params
  set_url:	string (not blank)

DELETE external_link
  created_at:	time range
  external_site:	external_site list
  id:	integer list
  observation:	observation list
  updated_at:	time range
  url:	string
  user:	user list (creator)

GET external_site
  id:	integer list
  name:	string

GET herbarium
  address:	string (postal address)
  code:	string
  created_at:	time range
  description:	string
  id:	integer list
  name:	string
  updated_at:	time range

GET image
  confidence:	confidence range (limit=-3..3)
  content_type:	enum list (limit=bmp|gif|jpg|png|raw|tiff)
  copyright_holder_has:	string (search within copyright holder)
  created_at:	time range
  date:	date range (when photo taken)
  has_notes:	boolean
  has_observation:	boolean (limit=true, is attached to an observation?)
  has_votes:	boolean
  id:	integer list
  include_subtaxa:	boolean
  include_synonyms:	boolean
  license:	license
  location:	location list
  name:	name list
  notes_has:	string (search within notes)
  observation:	observation list
  ok_for_export:	boolean
  project:	project list
  quality:	quality range (limit=1..4)
  size:	enum (limit=huge|large|medium|small|thumbnail, width or height at least 160 for thumbnail, 320 for small, 640 for medium, 960 for large, 1280 for huge)
  species_list:	species_list list
  updated_at:	time range
  user:	user list (who uploaded the photo)

POST image
  copyright_holder:	string (limit=100 chars)
  date:	date (when photo taken)
  license:	license
  notes:	string
  observations:	observation list (must have edit permission)
  original_name:	string (limit=120 chars, original file name or other private identifier)
  projects:	project list (must be member)
  upload:	upload
  upload_file:	string
  upload_url:	string
  vote:	enum (limit=1|2|3|4)

PATCH image
 query params
  confidence:	confidence range (limit=-3..3)
  content_type:	enum list (limit=bmp|gif|jpg|png|raw|tiff)
  copyright_holder_has:	string (search within copyright holder)
  created_at:	time range
  date:	date range (when photo taken)
  has_notes:	boolean
  has_observation:	boolean (limit=true, is attached to an observation?)
  has_votes:	boolean
  id:	integer list
  include_subtaxa:	boolean
  include_synonyms:	boolean
  license:	license
  location:	location list
  name:	name list
  notes_has:	string (search within notes)
  observation:	observation list
  ok_for_export:	boolean
  project:	project list
  quality:	quality range (limit=1..4)
  size:	enum (limit=huge|large|medium|small|thumbnail, width or height at least 160 for thumbnail, 320 for small, 640 for medium, 960 for large, 1280 for huge)
  species_list:	species_list list
  updated_at:	time range
  user:	user list (who uploaded the photo)
 update params
  set_copyright_holder:	string (limit=100 chars)
  set_date:	date (when photo taken)
  set_license:	license
  set_notes:	string
  set_original_name:	string (limit=120 chars, original file name or other private identifier)

DELETE image
  confidence:	confidence range (limit=-3..3)
  content_type:	enum list (limit=bmp|gif|jpg|png|raw|tiff)
  copyright_holder_has:	string (search within copyright holder)
  created_at:	time range
  date:	date range (when photo taken)
  has_notes:	boolean
  has_observation:	boolean (limit=true, is attached to an observation?)
  has_votes:	boolean
  id:	integer list
  include_subtaxa:	boolean
  include_synonyms:	boolean
  license:	license
  location:	location list
  name:	name list
  notes_has:	string (search within notes)
  observation:	observation list
  ok_for_export:	boolean
  project:	project list
  quality:	quality range (limit=1..4)
  size:	enum (limit=huge|large|medium|small|thumbnail, width or height at least 160 for thumbnail, 320 for small, 640 for medium, 960 for large, 1280 for huge)
  species_list:	species_list list
  updated_at:	time range
  user:	user list (who uploaded the photo)

GET location
  created_at:	time range
  east:	longitude (max longitude)
  id:	integer list
  north:	latitude (max latitude)
  south:	latitude (min latitude)
  updated_at:	time range
  user:	user list (creator / first to use)
  west:	longitude (min longitude)

POST location
  east:	longitude
  high:	altitude
  low:	altitude
  name:	string (limit=1024 chars, in postal format with country last regardless of user preference)
  north:	latitude
  notes:	string
  south:	longitude
  west:	longitude

PATCH location
 query params
  created_at:	time range
  east:	longitude (max longitude)
  id:	integer list
  north:	latitude (max latitude)
  south:	latitude (min latitude)
  updated_at:	time range
  user:	user list (creator / first to use)
  west:	longitude (min longitude)
 update params
  set_east:	longitude
  set_high:	altitude
  set_low:	altitude
  set_name:	string (limit=1024 chars, not blank, in postal format with country last regardless of user preference)
  set_north:	latitude
  set_notes:	string
  set_south:	longitude
  set_west:	longitude

GET name
  author_has:	string (search within author)
  citation_has:	string (search within citation)
  classification_has:	string (search within classification)
  comments_has:	string (search within comments summary and body)
  created_at:	time range
  has_author:	boolean
  has_citation:	boolean
  has_classification:	boolean
  has_comments:	boolean (limit=true)
  has_description:	boolean
  has_notes:	boolean
  has_synonyms:	boolean
  id:	integer list
  include_subtaxa:	boolean
  include_synonyms:	boolean
  is_deprecated:	boolean
  location:	string list
  misspellings:	enum (default=no, limit=either|no|only, include misspellings? "either" means do not care and "only" means only show misspelt names)
  name:	name list
  notes_has:	string (search within notes)
  ok_for_export:	boolean
  rank:	enum (limit=Class|Domain|Family|Form|Genus|Group|Kingdom|Order|Phylum|Section|Species|Stirps|Subgenus|Subsection|Subspecies|Variety)
  species_list:	string list
  text_name_has:	string (search within name)
  updated_at:	time range
  user:	user list (creator / first to use)

POST name
  author:	string (limit=100 chars)
  citation:	string
  classification:	string
  deprecated:	boolean (default=false)
  name:	string (limit=100 chars)
  notes:	string
  rank:	enum (limit=Class|Domain|Family|Form|Genus|Group|Kingdom|Order|Phylum|Section|Species|Stirps|Subgenus|Subsection|Subspecies|Variety)

PATCH name
 query params
  author_has:	string (search within author)
  citation_has:	string (search within citation)
  classification_has:	string (search within classification)
  comments_has:	string (search within comments summary and body)
  created_at:	time range
  has_author:	boolean
  has_citation:	boolean
  has_classification:	boolean
  has_comments:	boolean (limit=true)
  has_description:	boolean
  has_notes:	boolean
  has_synonyms:	boolean
  id:	integer list
  include_subtaxa:	boolean
  include_synonyms:	boolean
  is_deprecated:	boolean
  location:	string list
  misspellings:	enum (default=no, limit=either|no|only, include misspellings? "either" means do not care and "only" means only show misspelt names)
  name:	name list
  notes_has:	string (search within notes)
  ok_for_export:	boolean
  rank:	enum (limit=Class|Domain|Family|Form|Genus|Group|Kingdom|Order|Phylum|Section|Species|Stirps|Subgenus|Subsection|Subspecies|Variety)
  species_list:	string list
  text_name_has:	string (search within name)
  updated_at:	time range
  user:	user list (creator / first to use)
 update params
  clear_synonyms:	boolean (limit=true, make it so this name is not synonymized with anything but leave everything it used to be synonymized with synonyms of each other)
  set_author:	string (limit=100 chars)
  set_citation:	string
  set_classification:	string
  set_correct_spelling:	name (mark this as misspelt and deprecated and synonymize with the correct spelling)
  set_deprecated:	boolean
  set_name:	string (limit=100 chars)
  set_notes:	string
  set_rank:	enum (limit=Class|Domain|Family|Form|Genus|Group|Kingdom|Order|Phylum|Section|Species|Stirps|Subgenus|Subsection|Subspecies|Variety)
  synonymize_with:	name

GET observation
  comments_has:	string (search within comments summary and body)
  confidence:	confidence (limit=-3..3)
  created_at:	time range
  date:	date range (when seen)
  east:	longitude (max longitude)
  gps_hidden:	boolean (hide exact coordinates?)
  has_comments:	boolean (limit=true)
  has_images:	boolean
  has_location:	boolean
  has_name:	boolean (group or genus or better)
  has_notes:	boolean
  has_notes_field:	string list (is given observation notes template field filled in?)
  has_specimen:	boolean
  herbarium:	herbarium list
  herbarium_record:	herbarium_record list
  id:	integer list
  include_subtaxa:	boolean
  include_synonyms:	boolean
  is_collection_location:	boolean (is this location where mushroom was found?)
  location:	location list
  name:	name list
  north:	latitude (max latitude)
  notes_has:	string (search within notes)
  project:	project list
  region:	string (matches locations which end in this, e.g. "California, USA")
  south:	latitude (min latitude)
  species_list:	species_list list
  updated_at:	time range
  user:	user list (observer)
  west:	longitude (min longitude)

POST observation
  accession_number:	string (unique fungarium id)
  altitude:	altitude
  collection_number:	string
  collectors_name:	string
  date:	date
  gps_hidden:	boolean (default=false, hide exact coordinates?)
  has_specimen:	boolean
  herbarium:	herbarium
  images:	image list
  initial_det:	string (initial determination)
  is_collection_location:	boolean (default, is this location where mushroom was found?)
  latitude:	latitude
  location:	place_name (limit=1024 chars)
  log:	boolean (default, log this action on main page activity log and RSS feed?)
  longitude:	longitude
  name:	name (default=Fungi)
  notes:	string
  notes[$field]:	string (set value of the custom notes template field, substitute field name for "$field")
  projects:	project list (must be member)
  reason_1:	string
  reason_2:	string
  reason_3:	string
  reason_4:	string
  species_lists:	species_list list (must have edit permission)
  thumbnail:	image
  vote:	float (default=3)

PATCH observation
 query params
  comments_has:	string (search within comments summary and body)
  confidence:	confidence (limit=-3..3)
  created_at:	time range
  date:	date range (when seen)
  east:	longitude (max longitude)
  has_comments:	boolean (limit=true)
  has_images:	boolean
  has_location:	boolean
  has_name:	boolean (group or genus or better)
  has_notes:	boolean
  has_notes_field:	string list (is given observation notes template field filled in?)
  has_specimen:	boolean
  herbarium:	herbarium list
  herbarium_record:	herbarium_record list
  id:	integer list
  include_subtaxa:	boolean
  include_synonyms:	boolean
  is_collection_location:	boolean (is this location where mushroom was found?)
  location:	location list
  name:	name list
  north:	latitude (max latitude)
  notes_has:	string (search within notes)
  project:	project list
  region:	string (matches locations which end in this, e.g. "California, USA")
  south:	latitude (min latitude)
  species_list:	species_list list
  updated_at:	time range
  user:	user list (observer)
  west:	longitude (min longitude)
 update params
  add_images:	image list (must have edit permission)
  add_to_project:	project (must be member)
  add_to_species_list:	species_list (must have edit permission)
  gps_hidden:	boolean (hide exact coordinates?)
  log:	boolean (default, log this action on main page activity log and RSS feed?)
  remove_from_project:	project
  remove_from_species_list:	species_list (must have edit permission)
  remove_images:	image list
  set_altitude:	altitude
  set_date:	date
  set_has_specimen:	boolean
  set_is_collection_location:	boolean (is this location where mushroom was found?)
  set_latitude:	latitude
  set_location:	place_name (limit=1024 chars, not blank)
  set_longitude:	longitude
  set_notes:	string
  set_notes[$field]:	string (set value of the custom notes template field, substitute field name for "$field")
  set_thumbnail:	image (must have edit permission)

DELETE observation
  comments_has:	string (search within comments summary and body)
  confidence:	confidence (limit=-3..3)
  created_at:	time range
  date:	date range (when seen)
  east:	longitude (max longitude)
  gps_hidden:	boolean (hide exact coordinates?)
  has_comments:	boolean (limit=true)
  has_images:	boolean
  has_location:	boolean
  has_name:	boolean (group or genus or better)
  has_notes:	boolean
  has_notes_field:	string list (is given observation notes template field filled in?)
  has_specimen:	boolean
  herbarium:	herbarium list
  herbarium_record:	herbarium_record list
  id:	integer list
  include_subtaxa:	boolean
  include_synonyms:	boolean
  is_collection_location:	boolean (is this location where mushroom was found?)
  location:	location list
  name:	name list
  north:	latitude (max latitude)
  notes_has:	string (search within notes)
  project:	project list
  region:	string (matches locations which end in this, e.g. "California, USA")
  south:	latitude (min latitude)
  species_list:	species_list list
  updated_at:	time range
  user:	user list (observer)
  west:	longitude (min longitude)

GET project
  comments_has:	string (search within comments summary and body)
  created_at:	time range
  has_comments:	boolean (limit=true)
  has_images:	boolean (limit=true)
  has_observations:	boolean (limit=true)
  has_species_lists:	boolean (limit=true)
  has_summary:	boolean
  id:	integer list
  summary_has:	string (search within summary)
  title_has:	string (search within title)
  updated_at:	time range
  user:	user list (creator)

POST project
  admins:	user list
  members:	user list
  summary:	string
  title:	string (limit=100 chars)

PATCH project
 query params
  comments_has:	string (search within comments summary and body)
  created_at:	time range
  has_comments:	boolean (limit=true)
  has_images:	boolean (limit=true)
  has_observations:	boolean (limit=true)
  has_species_lists:	boolean (limit=true)
  has_summary:	boolean
  id:	integer list
  summary_has:	string (search within summary)
  title_has:	string (search within title)
  updated_at:	time range
  user:	user list (creator)
 update params
  add_admins:	user list
  add_images:	image list (must be owner)
  add_members:	user list
  add_observations:	observation list (must be owner)
  add_species_lists:	species_list list (must be owner)
  remove_admins:	user list
  remove_images:	image list
  remove_members:	user list
  remove_observations:	observation list
  remove_species_lists:	species_list list
  set_summary:	string
  set_title:	string (limit=100 chars, not blank)

GET sequence
  accession:	string list
  accession_has:	string (search within accession number)
  archive:	archive list (limit=ENA|GenBank|UNITE)
  confidence:	confidence (limit=-3..3)
  created_at:	time range
  east:	longitude (max longitude)
  has_images:	boolean
  has_name:	boolean (group or genus or better)
  has_notes_field:	string (is given observation notes template field filled in?)
  has_obs_notes:	boolean (observation has notes?)
  has_specimen:	boolean
  herbarium:	herbarium list
  herbarium_record:	herbarium_record list
  id:	integer list
  include_subtaxa:	boolean
  include_synonyms:	boolean
  is_collection_location:	boolean (is this location where mushroom was found?)
  location:	location list
  locus:	string list
  locus_has:	string (search within locus)
  name:	name list
  north:	latitude (max latitude)
  notes_has:	string (search within notes)
  obs_date:	date range (observation date)
  obs_notes_has:	string (search within observation notes)
  observer:	user list
  project:	project list
  south:	latitude (min latitude)
  species_list:	species_list list
  updated_at:	time range
  user:	user list (creator)
  west:	longitude (min longitude)

POST sequence
  accession:	string (limit=255 chars)
  archive:	archive (limit=ENA|GenBank|UNITE)
  bases:	string
  locus:	string
  notes:	string
  observation:	observation

PATCH sequence
 query params
  accession:	string list
  accession_has:	string (search within accession number)
  archive:	archive list (limit=ENA|GenBank|UNITE)
  confidence:	confidence (limit=-3..3)
  created_at:	time range
  east:	longitude (max longitude)
  has_images:	boolean
  has_name:	boolean (group or genus or better)
  has_notes_field:	string (is given observation notes template field filled in?)
  has_obs_notes:	boolean (observation has notes?)
  has_specimen:	boolean
  herbarium:	herbarium list
  herbarium_record:	herbarium_record list
  id:	integer list
  include_subtaxa:	boolean
  include_synonyms:	boolean
  is_collection_location:	boolean (is this location where mushroom was found?)
  location:	location list
  locus:	string list
  locus_has:	string (search within locus)
  name:	name list
  north:	latitude (max latitude)
  notes_has:	string (search within notes)
  obs_date:	date range (observation date)
  obs_notes_has:	string (search within observation notes)
  observer:	user list
  project:	project list
  south:	latitude (min latitude)
  species_list:	species_list list
  updated_at:	time range
  user:	user list (creator)
  west:	longitude (min longitude)
 update params
  set_accession:	string (limit=255 chars)
  set_archive:	archive (limit=ENA|GenBank|UNITE)
  set_bases:	string
  set_locus:	string (not blank)
  set_notes:	string

DELETE sequence
  accession:	string list
  accession_has:	string (search within accession number)
  archive:	archive list (limit=ENA|GenBank|UNITE)
  confidence:	confidence (limit=-3..3)
  created_at:	time range
  east:	longitude (max longitude)
  has_images:	boolean
  has_name:	boolean (group or genus or better)
  has_notes_field:	string (is given observation notes template field filled in?)
  has_obs_notes:	boolean (observation has notes?)
  has_specimen:	boolean
  herbarium:	herbarium list
  herbarium_record:	herbarium_record list
  id:	integer list
  include_subtaxa:	boolean
  include_synonyms:	boolean
  is_collection_location:	boolean (is this location where mushroom was found?)
  location:	location list
  locus:	string list
  locus_has:	string (search within locus)
  name:	name list
  north:	latitude (max latitude)
  notes_has:	string (search within notes)
  obs_date:	date range (observation date)
  obs_notes_has:	string (search within observation notes)
  observer:	user list
  project:	project list
  south:	latitude (min latitude)
  species_list:	species_list list
  updated_at:	time range
  user:	user list (creator)
  west:	longitude (min longitude)

GET species_list
  comments_has:	string (search within comments summary and body)
  created_at:	time range
  date:	date range (this date can mean anything you want)
  has_comments:	boolean (limit=true)
  has_notes:	boolean
  id:	integer list
  include_subtaxa:	boolean
  include_synonyms:	boolean
  location:	location list
  name:	name list
  notes_has:	string (search within notes)
  project:	project list
  title_has:	string (search within title)
  updated_at:	time range
  user:	user list (creator)

POST species_list
  date:	date
  location:	place_name (limit=1024 chars, default=Unknown)
  notes:	string
  title:	string (limit=100 chars)

PATCH species_list
 query params
  comments_has:	string (search within comments summary and body)
  created_at:	time range
  date:	date range (this date can mean anything you want)
  has_comments:	boolean (limit=true)
  has_notes:	boolean
  id:	integer list
  include_subtaxa:	boolean
  include_synonyms:	boolean
  location:	location list
  name:	name list
  notes_has:	string (search within notes)
  project:	project list
  title_has:	string (search within title)
  updated_at:	time range
  user:	user list (creator)
 update params
  add_observations:	observation list
  remove_observations:	observation list
  set_date:	date
  set_location:	place_name (limit=1024 chars, not blank)
  set_notes:	string
  set_title:	string (limit=100 chars, not blank)

DELETE species_list
  comments_has:	string (search within comments summary and body)
  created_at:	time range
  date:	date range (this date can mean anything you want)
  has_comments:	boolean (limit=true)
  has_notes:	boolean
  id:	integer list
  include_subtaxa:	boolean
  include_synonyms:	boolean
  location:	location list
  name:	name list
  notes_has:	string (search within notes)
  project:	project list
  title_has:	string (search within title)
  updated_at:	time range
  user:	user list (creator)

GET user
  created_at:	time range
  id:	integer list
  updated_at:	time range

POST user
  create_key:	string (if you pass in your app name here it will create an api key for the user for your app to use)
  email:	email (limit=80 chars)
  image:	image
  license:	license (default=varies)
  locale:	lang (default=en, limit=el|en|es|fr|pt|ru)
  location:	location
  login:	string (limit=80 chars)
  mailing_address:	string
  name:	string (limit=80 chars)
  notes:	string
  password:	string (limit=80 chars)

PATCH user
 query params
  created_at:	time range
  id:	integer list
  updated_at:	time range
 update params
  set_image:	image (must be owner)
  set_license:	license (not blank)
  set_locale:	lang (not blank, default=en, limit=el|en|es|fr|pt|ru)
  set_location:	location
  set_mailing_address:	string
  set_notes:	string

