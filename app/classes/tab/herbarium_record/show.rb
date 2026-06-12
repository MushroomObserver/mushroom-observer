# frozen_string_literal: true

# "Show this herbarium record" link. When `observation:` is set,
# narrows the prev/next navigation to that observation's
# herbarium_records via a scoped Query.
class Tab::HerbariumRecord::Show < Tab::Base
  def initialize(herbarium_record:, observation: nil)
    super()
    @herbarium_record = herbarium_record
    @observation = observation
  end

  def title
    @herbarium_record.accession_at_herbarium.t
  end

  def path
    args = @herbarium_record.show_link_args
    return args unless @observation

    args.merge(q: Query.lookup(:HerbariumRecord,
                               observations: @observation.id).q_param)
  end

  def alt_title
    "herbarium_record"
  end

  def model
    @herbarium_record
  end
end
