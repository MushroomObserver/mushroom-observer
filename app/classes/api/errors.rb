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

  # API request is missing request method.
  class MissingMethod < Error
  end

  # API request method not implemented for this endpoint.
  class NoMethodForAction < Error
    def initialize(method, action)
      super()
      args.merge!(method: method.to_s.upcase, action: action.to_s)
    end
  end

  # API endpoint doesn't exist.
  class BadAction < Error
    def initialize(action)
      super()
      args.merge!(action: action.to_s)
    end
  end

  # API request method not recognized.
  class BadMethod < Error
    def initialize(method)
      super()
      args.merge!(method: method.to_s)
    end
  end

  # API request ApiKey not valid.
  class BadApiKey < Error
    def initialize(str)
      super()
      args.merge!(key: str.to_s)
    end
  end

  # API request ApiKey not verified yet.
  class ApiKeyNotVerified < Error
    def initialize(key)
      super()
      args.merge!(key: key.key.to_s, notes: key.notes.to_s)
    end
  end

  # API request user not verified yet.
  class UserNotVerified < Error
    def initialize(user)
      super()
      args.merge!(login: user.login)
    end
  end

  # API request version syntax wrong.
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

  # API request missing required parameter.
  class MissingParameter < Error
    def initialize(arg)
      super()
      args.merge!(arg: arg.to_s)
    end
  end

  # API PATCH request missing all set parameters.
  class MissingSetParameters < Error
  end

  # API request parameter has bad syntax.
  class BadParameterValue < Error
    def initialize(str, type)
      super()
      args.merge!(val: str.to_s, type: type)
      self.tag = :"api_bad_#{type}_parameter_value"
    end
  end

  # API request parameter value out of range.
  class BadLimitedParameterValue < Error
    def initialize(str, limit)
      super()
      args.merge!(val: str.to_s, limit: limit.inspect)
    end
  end

  # API request string parameter too long.
  class StringTooLong < Error
    def initialize(str, length)
      super()
      args.merge!(val: str.to_s, limit: length.inspect)
    end
  end

  # API request name parameter has multiple matches.
  class AmbiguousName < Error
    def initialize(name, others)
      super()
      str = others.map(&:real_search_name).join(" / ")
      args.merge!(name: name.to_s, others: str)
    end
  end

  # Error while executing API request query.
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

  # API request included unexpected parameters.
  class UnusedParameters < Error
    def initialize(params)
      super()
      args.merge!(params: params.map(&:to_s).sort.join(", "))
    end
  end

  # API request inclues an unexpected upload.
  class UnexpectedUpload < Error
  end

  # API help message.
  class HelpMessage < Error
    def initialize(params)
      super()
      help = params.keys.sort_by(&:to_s).map do |arg|
        params[arg].inspect
      end.join("\n")
      args.merge!(help: help)
    end
  end

  ##############################################################################

  # API request requires valid ApiKey.
  class MustAuthenticate < Error
  end

  # API request attempted to alter something that requires edit permission.
  class MustHaveEditPermission < ObjectError
  end

  # API request attempted to view something that requires view permission.
  class MustHaveViewPermission < ObjectError
  end

  # API request requires you to be project admin.
  class MustBeAdmin < Error
    def initialize(proj)
      super()
      args.merge!(project: proj.title)
    end
  end

  # API request requires you to be project member.
  class MustBeMember < ObjectError
  end

  # API request to post external link requires certain permissions.
  class ExternalLinkPermissionDenied < Error
  end

  ##############################################################################

  # API request requires upload.
  class MissingUpload < Error
  end

  # API request supplied too many uploads.
  class TooManyUploads < Error
  end

  # API upload was supposed to be a local file, but it doesn't exist.
  class FileMissing < Error
    def initialize(file)
      super()
      args.merge(file: file.to_s)
    end
  end

  # API upload was supposed to be a URL, but couldn't get download it.
  class CouldntDownloadURL < Error
    def initialize(url, error)
      super()
      args.merge!(url: url.to_s, error: "#{error.class.name}: #{error}")
    end
  end

  # API upload didn't make it.
  class ImageUploadFailed < Error
    def initialize(img)
      super()
      args.merge!(error: img.dump_errors)
    end
  end

  ##############################################################################

  # API POST request couldn't create object.
  class CreateFailed < ObjectError
    def initialize(obj)
      super(obj)
      args.merge!(error: obj.formatted_errors.map(&:to_s).join("; "))
    end
  end

  # API DELETE request couldn't destroy object.
  class DestroyFailed < ObjectError
  end

  # API request must supply both latitude and longitude, can't leave one out.
  class LatLongMustBothBeSet < Error
  end

  # API request to create observation must supply either location or lat/long.
  class MustSupplyLocationOrGPS < Error
  end

  # API request tried to create/rename a location over top of an existing one.
  class LocationAlreadyExists < Error
    def initialize(str)
      super()
      args.merge!(location: str.to_s)
    end
  end

  # API request tried to create/rename a name over top of an existing one.
  class NameAlreadyExists < Error
    def initialize(str, name)
      super()
      args.merge!(new: str.to_s, old: name.real_search_name)
    end
  end

  # API request species name isn't valid.
  class NameDoesntParse < Error
    def initialize(str)
      super()
      args.merge!(name: str.to_s)
    end
  end

  # API request tried to create user that already exists.
  class UserAlreadyExists < Error
    def initialize(str)
      super()
      args.merge!(login: str)
    end
  end

  # API request referenced object id doesn't exist.
  class ObjectNotFoundById < Error
    def initialize(id, model)
      super()
      args.merge!(id: id.to_s, type: model.type_tag)
    end
  end

  # API request referenced object name doesn't exist.
  class ObjectNotFoundByString < Error
    def initialize(str, model)
      super()
      args.merge!(str: str.to_s, type: model.type_tag)
    end
  end

  # API request tried to create project that already exists.
  class ProjectTaken < Error
    def initialize(title)
      super()
      args.merge!(title: title.to_s)
    end
  end

  # API request tried to change location name to one that already exists.
  class TryingToSetMultipleLocationsToSameName < Error
  end

  # API request tried to update name/author/rank of more than one name at once.
  class TryingToSetMultipleNamesAtOnce < Error
  end

  # API request tried to create a user group that already exists.
  class UserGroupTaken < Error
    def initialize(title)
      super()
      args.merge!(title: title.to_s)
    end
  end

  # API request tried to set specimen info without claiming specimen present.
  class CanOnlyUseThisFieldIfHasSpecimen < Error
    def initialize(field)
      super()
      args.merge!(field: field)
    end
  end

  # API request to attach specimen had bpth specimen_id and herbarium_label.
  class CanOnlyUseOneOfTheseFields < Error
    def initialize(*fields)
      super()
      args.merge!(fields: fields.join(", "))
    end
  end

  # API request specifying bounding box is missing one or more edges of box.
  class NeedAllFourEdges < Error
  end

  # API request to create or update location has "dubious" location name.
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

  # API request to create or update name had invalid classification string.
  class BadClassification < Error
  end

  # API request tried to both clear synonyms and add synonyms at the same time.
  class OneOrTheOther < Error
    def initialize(arg1, arg2)
      super()
      args.merge!(arg1: arg1, arg2: arg2)
    end
  end

  # Not allowing client to merge to sets of synonyms.  Even more, we're
  # only allowing them to synonymize unsynonmized names with other names.
  # (The name they synonymize it with, however, can have synonyms.)
  class CanOnlySynonymizeUnsynonimizedNames < Error
  end
end
