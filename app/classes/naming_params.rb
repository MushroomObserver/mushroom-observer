# frozen_string_literal: true

# Encapsulates parameters needed for NamingController pages
class NamingParams
  attr_accessor :naming, :observation, :vote
  attr_reader :what, :name, :names, :valid_names, :reasons, :parent_deprecated,
              :suggest_corrections

  def initialize(what = "")
    @naming = Naming.new
    @vote = Vote.new
    @what = what.to_s # can't be nil else rails tries to call @name.name
    @reasons = @naming.init_reasons
  end

  def resolve_name(given_name, approved_name, chosen_name)
    (success, @what, @name, @names, @valid_names,
     @parent_deprecated, @suggest_corrections) =
      Name.resolve_name(given_name, approved_name, chosen_name)
    success && @name
  end

  def rough_draft(naming_args, vote_args,
                  name_str = nil, approved_name = nil, chosen_name = nil)
    @naming = Naming.construct(naming_args, @observation)
    @vote = Vote.construct(vote_args, @naming)
    result = if name_str
               resolve_name(name_str, approved_name, chosen_name)
             else
               true
             end
    @naming.name = @name
    result
  end

  def edit_init
    @what        = @naming.text_name
    @names       = nil
    @valid_names = nil
    @reasons     = @naming.init_reasons
  end

  def name_missing?
    if @name && @what.match(/\S/)
      false
    else
      @naming.errors.add(:name,
                         :form_observations_there_is_a_problem_with_name.t)
      true
    end
  end

  def name_not_changing?
    @naming.name == @name
  end

  def need_new_naming?
    !(@naming.editable? || name_not_changing?)
  end

  def add_reasons(reasons)
    @reasons = @naming.init_reasons(reasons)
  end

  def name_been_proposed?
    @observation.name_been_proposed?(@name)
  end

  def logged_change_vote
    @observation.logged_change_vote(@naming, @vote)
  end

  def update_name(user, reasons, was_js_on)
    @naming.update_name(@name, user, reasons, was_js_on)
  end

  def change_vote(new_val)
    if new_val && (!@vote || @vote.value != new_val)
      @observation.change_vote(@naming, new_val)
    else
      @observation.reload
      @observation.calc_consensus
    end
  end

  def save_vote
    @observation.reload
    @observation.change_vote(@naming, @vote.value)
    @observation.log(:log_naming_created, name: @naming.format_name)
  end

  def update_naming(reasons, was_js_on)
    @naming.name = @name
    @naming.create_reasons(reasons, was_js_on)
  end
end
