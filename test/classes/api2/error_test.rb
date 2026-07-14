# frozen_string_literal: true

require("test_helper")

# Exercises every API2 error class that has a custom constructor: builds each
# with representative args and asserts it derives a tag and renders. This
# covers the constructor bodies — never hit by the rest of the suite, since
# tests rarely trigger these specific error paths — and guards the
# error->translation contract (a missing en.txt key or broken arg
# interpolation would surface here).
class API2::ErrorTest < UnitTestCase
  def setup
    # The cases below reference every API2 error class by constant. These
    # live under the API2 namespace and are not reliably autoloaded on first
    # reference, so eager-load to make them all available regardless of test
    # order (the coverage test also depends on every subclass being loaded).
    Rails.application.eager_load!
  end

  def test_errors_construct_and_render
    error_cases.each do |klass, args|
      error = klass.new(*args)

      assert_kind_of(Symbol, error.tag, "#{klass}#tag")
      assert(error.tag.to_s.start_with?("api"),
             "#{klass} tag should start with 'api', got #{error.tag}")
      assert_kind_of(String, error.to_s, "#{klass}#to_s")
      assert_kind_of(String, error.inspect, "#{klass}#inspect")
    end
  end

  def test_error_message_interpolation
    assert_includes(API2::BadMethod.new("frobnicate").to_s, "frobnicate")
    assert_includes(API2::MissingParameter.new("name").to_s, "name")
    assert_includes(API2::ObjectNotFoundById.new(42, Observation).to_s, "42")
    # Also exercise the textile renderer (Error#t), not just to_s (Error#l).
    assert_kind_of(String, API2::BadMethod.new("frobnicate").t)
  end

  # Fails when a new API2 error with a custom constructor is added but not
  # listed in error_cases, so this coverage stays complete over time.
  def test_every_custom_constructor_is_covered
    all = ObjectSpace.each_object(Class).select do |c|
      c < API2::Error && c.instance_method(:initialize).owner == c
    end
    # Error, FatalError, and ObjectError are abstract bases never raised
    # directly; their constructor bodies are covered transitively when their
    # subclasses (below) are built.
    abstract = [API2::Error, API2::FatalError, API2::ObjectError]
    uncovered = (all - error_cases.keys - abstract).map(&:name).sort

    assert_empty(uncovered, "Add these API2 errors to error_cases")
  end

  private

  def error_cases
    scalar_arg_cases.
      merge(multi_arg_cases).
      merge(object_arg_cases)
  end

  def scalar_arg_cases
    {
      API2::BadAPIKey => ["bad-key"],
      API2::BadAction => ["frobnicate"],
      API2::BadMethod => ["frobnicate"],
      API2::BadVersion => ["9.9"],
      API2::CanOnlyUseThisFieldIfHasSpecimen => ["herbarium_label"],
      API2::DubiousLocationName => [["reason one", "reason two."]],
      API2::ExternalLinkAlreadyExists => ["https://example.org/1"],
      API2::FieldSlipAPI::CodeAlreadyUsed => ["ABC-1"],
      API2::FileMissing => ["photo.jpg"],
      API2::HelpMessage => [{}],
      API2::LocationAlreadyExists => ["Somewhere, USA"],
      API2::MissingParameter => ["name"],
      API2::MustBeCreator => [:observation],
      API2::MustBeOnlyEditor => [:observation],
      API2::MustOwnAllDescriptions => [:name],
      API2::MustOwnAllNamings => [:observation],
      API2::MustOwnAllObservations => [:observation],
      API2::MustOwnAllSpeciesLists => [:species_list],
      API2::NameAlreadyExists => ["Agaricus"],
      API2::NameDoesntParse => ["!!bad!!"],
      API2::OneOrTheOther => [%w[a b]],
      API2::ParameterCantBeBlank => ["name"],
      API2::ProjectTaken => ["My Project"],
      API2::SpeciesListAlreadyExists => ["My List"],
      API2::UnusedParameters => [[:foo, :bar]],
      API2::UserAlreadyExists => ["rolf"],
      API2::UserGroupTaken => ["My Group"]
    }
  end

  def multi_arg_cases
    {
      API2::BadLimitedParameterValue => ["huge", 32],
      API2::BadParameterValue => ["x", :integer],
      API2::CouldntDownloadURL => ["http://x/y.jpg", RuntimeError.new("boom")],
      API2::NameWrongForRank => %w[Agaricus Genus],
      API2::NoMethodForAction => %w[get frobnicate],
      API2::ObjectNotFoundById => [42, Observation],
      API2::ObjectNotFoundByString => ["Foo", Observation],
      API2::QueryError => [RuntimeError.new("bad query")],
      API2::RenderFailed => [raised_exception],
      API2::StringTooLong => ["toolong", 3]
    }
  end

  def object_arg_cases
    {
      API2::APIKeyNotVerified => [api_keys(:rolfs_api_key)],
      API2::AmbiguousName => ["Foo", [names(:fungi)]],
      API2::CreateFailed => [observations(:minimal_unknown_obs)],
      API2::FieldSlipInUse => [field_slips(:field_slip_one)],
      API2::HerbariumRecordAlreadyExists =>
        [herbarium_records(:interesting_unknown)],
      API2::ImageUploadFailed => [Image.new],
      API2::MustBeAdmin => [projects(:eol_project)],
      API2::UserAccountBlocked => [users(:rolf)],
      API2::UserNotVerified => [users(:rolf)]
    }
  end

  def raised_exception
    raise("kaboom")
  rescue StandardError => e
    e
  end
end
