class API
  # API exception base class.
  class Error < ::StandardError
    attr_accessor :tag, :args, :fatal, :trace

    def initialize
      self.tag = self.class.name.underscore.tr("/", "_").to_sym
      self.args = {}
      self.fatal = false
      self.trace = caller
    end

    def inspect
      "#{self.class.name}(:#{tag}#{args.inspect})"
    end

    def to_s
      tag.l(args)
    end

    def t
      tag.t(args)
    end
  end

  # API exception base class for errors having to do with database records.
  class ObjectError < Error
    def initialize(obj)
      super()
      args.merge!(type: obj.type_tag, name: display_name(obj))
    end

    def display_name(obj)
      if obj.respond_to?(:unique_text_name)
        obj.unique_text_name
      elsif obj.respond_to?(:display_name)
        obj.display_name
      elsif obj.respond_to?(:name)
        obj.name
      elsif obj.respond_to?(:title)
        obj.title
      else
        "##{obj.id}"
      end
    end
  end

  ##############################################################################

  # Missing request method.
  class MissingMethod < Error
  end

  # Method not implemented for this endpoint.
  class NoMethodForAction < Error
    def initialize(method, action)
      super()
      args.merge!(method: method.to_s.upcase, action: action.to_s)
    end
  end

  # Endpoint doesn't exist.
  class BadAction < Error
    def initialize(action)
      super()
      args.merge!(action: action.to_s)
    end
  end

  # Request method not recognized.
  class BadMethod < Error
    def initialize(method)
      super()
      args.merge!(method: method.to_s)
    end
  end

  # ApiKey not valid.
  class BadApiKey < Error
    def initialize(str)
      super()
      args.merge!(key: str.to_s)
    end
  end

  # ApiKey not verified yet.
  class ApiKeyNotVerified < Error
    def initialize(key)
      super()
      args.merge!(key: key.key.to_s, notes: key.notes.to_s)
    end
  end

  # User not verified yet.
  class UserNotVerified < Error
    def initialize(user)
      super()
      args.merge!(login: user.login)
    end
  end

  # Syntax of requested version is wrong.
  class BadVersion < Error
    def initialize(str)
      super()
      args.merge!(version: str.to_s)
    end
  end

  # Error rendering API request results.
  class RenderFailed < Error
    def initialize(error)
      super()
      msg = error.to_s + "\n" + error.backtrace.join("\n")
      args.merge!(error: msg)
    end
  end

  ##############################################################################

  # Missing required parameter.
  class MissingParameter < Error
    def initialize(arg)
      super()
      args.merge!(arg: arg.to_s)
    end
  end

  # PATCH request missing all set parameters.
  class MissingSetParameters < Error
  end

  # Parameter has bad syntax.
  class BadParameterValue < Error
    def initialize(str, type)
      super()
      args.merge!(val: str.to_s, type: type)
      self.tag = :"api_bad_#{type}_parameter_value"
    end
  end

  # Parameter value out of range.
  class BadLimitedParameterValue < Error
    def initialize(str, limit)
      super()
      args.merge!(val: str.to_s, limit: limit.inspect)
    end
  end

  # Notes template field didn't parse.
  class BadNotesFieldParameter < Error
    def initialize(str)
      super()
      args.merge!(val: str.to_s)
    end
  end

  # Some PATCH set parameters, if supplied, cannot be blank.
  class ParameterCantBeBlank < Error
    def initialize(arg)
      super()
      args.merge!(arg: arg.to_s)
    end
  end

  # String parameter too long.
  class StringTooLong < Error
    def initialize(str, length)
      super()
      args.merge!(val: str.to_s, limit: length.inspect)
    end
  end

  # Name parameter has multiple matches.
  class AmbiguousName < Error
    def initialize(name, others)
      super()
      str = others.map(&:real_search_name).join(" / ")
      args.merge!(name: name.to_s, others: str)
    end
  end

  # Error while executing query.
  class QueryError < Error
    def initialize(error)
      super()
      args.merge!(error: error.to_s)
    end
  end

  ##############################################################################

  # Error thrown when PATCH or DELETE abort from errors before doing anything.
  class AbortDueToErrors < Error
  end

  # Request included unexpected parameters.
  class UnusedParameters < Error
    def initialize(params)
      super()
      args.merge!(params: params.map(&:to_s).sort.join(", "))
    end
  end

  # Request includes an unexpected upload.
  class UnexpectedUpload < Error
  end

  # API auto-discover help message.
  class HelpMessage < Error
    attr_accessor :params

    def initialize(params)
      super()
      self.params = params
      args.merge!(help: help_message)
    end

    def help_message
      if keys_for_patch.any?
        "query params: " + render_keys(keys_for_get) +
          "; update params: " + render_keys(keys_for_patch)
      else
        render_keys(all_keys)
      end
    end

    def render_keys(keys)
      keys.sort_by(&:to_s).map do |arg|
        params[arg].inspect
      end.join("; ")
    end

    def all_keys
      params.keys - [
        :method, :action, :version, :api_key, :page, :detail, :format
      ]
    end

    def keys_for_get
      all_keys.reject { |k| params[k].set_parameter? }
    end

    def keys_for_patch
      all_keys.select { |k| params[k].set_parameter? }
    end
  end

  ##############################################################################

  # Request requires valid ApiKey.
  class MustAuthenticate < Error
  end

  # Attempted to add object you don't own to a project.
  class MustBeOwner < ObjectError
  end

  # Attempted to alter something that requires edit permission.
  class MustHaveEditPermission < ObjectError
  end

  # Attempted to view something that requires view permission.
  class MustHaveViewPermission < ObjectError
  end

  # Request requires you to be project admin.
  class MustBeAdmin < Error
    def initialize(proj)
      super()
      args.merge!(project: proj.title)
    end
  end

  # Request requires you to be project member.
  class MustBeMember < ObjectError
  end

  # Request to post external link requires certain permissions.
  class ExternalLinkPermissionDenied < Error
  end

  # Tried to add herbarium record to observation that you don't own, and you
  # are not a curator of the herbarium.
  class CantAddHerbariumRecord < Error
  end

  ##############################################################################

  # Request requires upload.
  class MissingUpload < Error
  end

  # Request supplied too many uploads.
  class TooManyUploads < Error
  end

  # Upload was supposed to be a local file, but it doesn't exist.
  class FileMissing < Error
    def initialize(file)
      super()
      args.merge(file: file.to_s)
    end
  end

  # Upload was supposed to be a URL, but couldn't get download it.
  class CouldntDownloadURL < Error
    def initialize(url, error)
      super()
      args.merge!(url: url.to_s, error: "#{error.class.name}: #{error}")
    end
  end

  # Upload didn't make it.
  class ImageUploadFailed < Error
    def initialize(img)
      super()
      args.merge!(error: img.dump_errors)
    end
  end

  ##############################################################################

  # POST request couldn't create object.
  class CreateFailed < ObjectError
    def initialize(obj)
      super(obj)
      args.merge!(error: obj.formatted_errors.map(&:to_s).join("; "))
    end
  end

  # Must supply both latitude and longitude, can't leave one out.
  class LatLongMustBothBeSet < Error
  end

  # Tried to create/rename a location over top of an existing one.
  class LocationAlreadyExists < Error
    def initialize(str)
      super()
      args.merge!(location: str.to_s)
    end
  end

  # Tried to create/rename a name over top of an existing one.
  class NameAlreadyExists < Error
    def initialize(str)
      super()
      args.merge!(new: str.to_s, old: str.to_s)
    end
  end

  # Taxon name isn't valid.
  class NameDoesntParse < Error
    def initialize(str)
      super()
      args.merge!(name: str.to_s)
    end
  end

  # Taxon name isn't valid for the given rank.
  class NameWrongForRank < Error
    def initialize(str, rank)
      super()
      args.merge!(name: str.to_s, rank: :"rank_#{rank}")
    end
  end

  # Tried to create species list that already exists.
  class SpeciesListAlreadyExists < Error
    def initialize(str)
      super()
      args.merge!(title: str)
    end
  end

  # Tried to create user that already exists.
  class UserAlreadyExists < Error
    def initialize(str)
      super()
      args.merge!(login: str)
    end
  end

  # Tried to create herbarium record already been used by someone else.
  class HerbariumRecordAlreadyExists < Error
    def initialize(obj)
      super()
      args.merge!(herbarium: obj.herbarium.name, number: obj.accession_number)
    end
  end

  # Referenced object id doesn't exist.
  class ObjectNotFoundById < Error
    def initialize(id, model)
      super()
      args.merge!(id: id.to_s, type: model.type_tag)
    end
  end

  # Referenced object name doesn't exist.
  class ObjectNotFoundByString < Error
    def initialize(str, model)
      super()
      args.merge!(str: str.to_s, type: model.type_tag)
    end
  end

  # Tried to create project that already exists.
  class ProjectTaken < Error
    def initialize(title)
      super()
      args.merge!(title: title.to_s)
    end
  end

  # Tried to update name of more than one location at once.
  class TryingToSetMultipleLocationsToSameName < Error
  end

  # Tried to update name/author/rank of more than one name at once.
  class TryingToSetMultipleNamesAtOnce < Error
  end

  # Tried to create a user group that already exists.
  class UserGroupTaken < Error
    def initialize(title)
      super()
      args.merge!(title: title.to_s)
    end
  end

  # Tried to set herbarium_record info without claiming specimen present.
  class CanOnlyUseThisFieldIfHasSpecimen < Error
    def initialize(field)
      super()
      args.merge!(field: field)
    end
  end

  # Can't set both specimen_id and herbarium_label, choose one or the other.
  class CanOnlyUseOneOfTheseFields < Error
    def initialize(*fields)
      super()
      args.merge!(fields: fields.join(", "))
    end
  end

  # Bounding box is missing one or more edges.
  class NeedAllFourEdges < Error
  end

  # Location name is "dubious".
  class DubiousLocationName < Error
    def initialize(reasons)
      super()
      args.merge!(reasons: reasons.join("; ").gsub(/\.;/, ";"))
    end
  end

  # Cannot update location if another user has made it their profile location.
  class AnotherUsersProfileLocation < Error
  end

  # Can only update locations/names which you have created.
  class MustBeCreator < Error
    def initialize(type)
      super()
      args.merge!(type: type)
    end
  end

  # Cannot update locations/names which other users have edited.
  class MustBeOnlyEditor < Error
    def initialize(type)
      super()
      args.merge!(type: type)
    end
  end

  # Cannot update locations if there is an herbarium there.
  class MustNotHaveAnyHerbaria < Error
  end

  # Can only update locations/names which you own all the desrciptions for.
  class MustOwnAllDescriptions < Error
    def initialize(type)
      super()
      args.merge!(type: type)
    end
  end

  # Can only update names which no one else has proposed on any observations.
  class MustOwnAllNamings < Error
    def initialize(type)
      super()
      args.merge!(type: type)
    end
  end

  # Cannot update location/name unless you own all its observations.
  class MustOwnAllObservations < Error
    def initialize(type)
      super()
      args.merge!(type: type)
    end
  end

  # Cannot update location unless you own all its species lists.
  class MustOwnAllSpeciesLists < Error
    def initialize(type)
      super()
      args.merge!(type: type)
    end
  end

  # Invalid classification string.
  class BadClassification < Error
  end

  # Tried to both clear synonyms and add synonyms at the same time.
  class OneOrTheOther < Error
    def initialize(args)
      super()
      args.merge!(args: args.map(&:to_s).join(", "))
    end
  end

  # We're not allowing client to merge to sets of synonyms.  Even more, we're
  # only allowing them to synonymize unsynonmized names with other names.
  # (The name they synonymize it with, however, can have synonyms.)
  class CanOnlySynonymizeUnsynonimizedNames < Error
  end
end
