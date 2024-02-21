# frozen_string_literal: true

#  = API2
#
#  == Usage
#
#    api = API2.execute(method: "GET", action: :observation, id: 12345)
#    unless api.errors.any?
#      render_results(api.results)
#    else
#      render_errors(api.errors)
#    end
#
#  All requests return an array of objects affected, and an array of any
#  errors.  There are four basic types of request:
#
#    # GET: Retrieve all jason's observations:
#    api = API2.execute(method: "GET", action: :observation, user: 'jason')
#    observations = api.results
#
#    # POST: Post new observation:
#    api = API2.execute(method: "POST", action: :observation, when: 1.month.ago,
#                      etc...)
#    new_observation = api.results.first
#
#    # PATCH: Set the notes in all your observations from 23 May 2012:
#    api = API2.execute(method: "PATCH", action: :observation, when:
#                      '2012-05-23', set_notes: 'on rock')
#    updated_observations = api.results
#
#    # DELETE: Destroy all your observations from May 2012:
#    api = API2.execute(method: "DELETE", action: :observation, when: '2012-05')
#    dead_observations = api.results
#
#  == Queries
#
#  The +action+ argument corresponds to a subclass of API2.  For example,
#  :observation corresponds to API2::Observation.  The primary actions each
#  correspond to one of the main object types:
#
#    :api_key               APIKey's
#    :comment               Comment's (on observations, names, etc.)
#    :image                 Image's
#    :image_vote            Vote's on image quality
#    :location              Location's
#    :location_description  LocationDescription's
#    :name                  Scientific Name's
#    :name_description      NameDescription's
#    :naming                Name proposals for observations
#    :observation           Observation's
#    :project               Project's
#    :species_list          SpeciesList's (list of Observation's)
#    :user                  User's
#    :vote                  Vote's on name proposals for observations
#
#  These each have a uniform interface.  GET, PATCH and DELETE requests all
#  take a variety of standard "search" parameters, e.g.:
#
#    id: '12345'          Select object id #12345.
#    id: '12345-12356'    Select objects whose ids are between 12345 and 12356,
#                         inclusive.
#    user: '252'          Select objects belonging to user #252.
#    user: 'fred'         Select objects belonging to user 'fred'.
#    user: 'fred,jason'   Select objects belonging to any of several users.
#    date: '2009'         Select objects created in 2009.
#    date: '6-8'          Select objects created in June through August,
#                         any year.
#
#  Note that all values are strings, such as you would send as parameters in a
#  simple URL.  Multiple search conditions are combined intersectively, i.e.
#  cond_1 AND cond_2 AND ...  Unions must be constructed with multiple queries.
#
#  GET requests return an array of matching objects.  DELETE requests attempt
#  to destroy all matching objects.  PATCH requests allow users to make one or
#  more changes to all matching objects.  Changes are specified with "set"
#  parameters, e.g.:
#
#    set_date: '2009-07-31'      Change date to 20090731.
#    set_location: 'California'  Change location (can also take ID).
#    set_specimen: 'true'        Tell it that you have a specimen.
#
#  Multiple set parameters are allowed, in which case it attempts to make each
#  of the changes to all matching objects.
#
#  POST requests attempt to create a new object and return the resulting
#  object.  Creating multiple objects requires multiple requests.  In this
#  case, use only the "set" parameters above.
#
#  Authentication for PATCH, POST, DELETE methods is accomplished by passing in
#  an API key.  Users can create one or more API keys via the API Key Manager
#  available on their Preferences and Profile page:
#
#    api_key: 'sdF78aw32KM23d9J23FJgseR87f32'
#
#  To find a full list of arguments allowed for each pair of (method, action)
#  look at the documentation for that subclass.
#
#    API2::UserAPI#get          Method used to GET users.
#    API2::NameAPI#patch        Method used to PATCH names.
#    API2::ObservationAPI#post  Method used to POST observations.
#    API2::ImageAPI#delete      Method used to DELETE images.
#
#  == Attributes
#
#  args::                 Original hash of arguments passed in.
#  results::              List of objects found / updated.
#  errors::               List of errors.
#  user::                 Authenticated user making request.
#  api_key::              APIKey used to authenticate.
#  version::              Version number of this request.
#  query::                Rough copy of SQL query used.
#  number::               Number of matching objects.
#  page::                 Current page number.
#  pages::                Number of pages available.
#
class API2
  API_VERSION = 2.0

  include Helpers
  include Uploads
  include Results
  include Parameters
  include Base

  def self.version
    API_VERSION
  end

  attr_accessor :params, :method, :action, :version, :user, :api_key, :errors

  ### PARAMETERS ###

  attr_accessor :expected_params, :ignore_params

  def initialize_parameters
    self.expected_params = {}
    self.ignore_params   = {}
    parse(:string, :action)
  end

  ### RESULTS ###

  def model
  end

  def high_detail_includes
    []
  end

  def low_detail_includes
    []
  end

  def high_detail_page_length
    10
  end

  def low_detail_page_length
    100
  end

  def put_page_length
    1000
  end

  def delete_page_length
    1000
  end

  attr_accessor :query, :detail, :page_number

  def initialize_results
    self.detail = parse(:enum, :detail, limit: [:none, :low, :high]) || :none
    self.page_number = parse(:integer, :page, default: 1)
  end
end
