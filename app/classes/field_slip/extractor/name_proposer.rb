# frozen_string_literal: true

class FieldSlip
  module Extractor
    # Turns the reviewed ID into a proposed naming on the observation.
    #
    # Not part of `Applier`: every other field is an attribute write,
    # while this creates a Naming and a Vote attributed to the reviewer,
    # and can need a second round-trip when the name is unrecognized or
    # ambiguous. Routed through `Naming::NameResolver` -- the same
    # resolver the observation form uses -- so an unrecognized name gets
    # created exactly as it would there, including the confirmation step
    # rather than silently minting a Name from a machine reading.
    class NameProposer
      # "Promising": a slip's ID is the collector's determination,
      # worth more than a guess and less than the reviewer's own
      # certainty. Matches the form's default; this is the fallback for
      # a submission that carries no vote at all.
      DEFAULT_VOTE = Vote::NEXT_BEST_VOTE

      # :none    nothing to propose
      # :needs_approval  resolver wants a confirmation round-trip
      # :proposed        naming + vote created
      Outcome = Data.define(:status, :naming, :feedback) do
        def needs_approval? = status == :needs_approval
        def proposed? = status == :proposed
      end

      # `name_params` takes the same shape `Naming::NameResolver` does
      # -- given_name / approved_name / chosen_name -- so the round-trip
      # params pass straight through instead of being renamed twice.
      def initialize(observation:, user:, name_params:, vote: nil)
        @observation = observation
        @user = user
        @given_name = name_params[:given_name].to_s.strip
        @approved_name = name_params[:approved_name].to_s
        @chosen_name = name_params[:chosen_name].to_s
        @vote = vote
      end

      def propose
        return none if @given_name.blank?

        resolver = resolve
        # Three outcomes, not two. The resolver returns early on a
        # placeholder like "unknown" -- success stays true and no name
        # comes back -- which means there is nothing to propose, NOT
        # that a name needs creating. Collapsing that into
        # needs_approval sent the reviewer to a confirmation page whose
        # feedback panel renders empty: a dead end with no way forward.
        return propose_naming(resolver.name) if resolver.name
        return none if resolver.success

        needs_approval(resolver)
      end

      private

      def resolve
        Naming::NameResolver.new(@user, given_name: @given_name,
                                        approved_name: @approved_name,
                                        chosen_name: @chosen_name)
      end

      def none = Outcome.new(status: :none, naming: nil, feedback: {})

      # The resolver's own ivars are what the form needs to render its
      # "create this name?" / "which of these?" feedback, so they are
      # handed back whole rather than reinterpreted here.
      def needs_approval(resolver)
        Outcome.new(status: :needs_approval, naming: nil,
                    feedback: resolver.results.except(:success))
      end

      # Reuse this user's existing naming for the name if there is one:
      # a reviewer who saves the same review twice (a re-review, a
      # rescan) is restating one reading, not proposing it again, so
      # this must not stack duplicate namings on the observation.
      def propose_naming(name)
        naming = @observation.namings.find_by(user: @user, name: name) ||
                 build_naming(name)
        cast_vote(naming)
        Outcome.new(status: :proposed, naming: naming, feedback: {})
      end

      def build_naming(name)
        naming = Naming.construct({}, @observation)
        naming.name = name
        naming.user = @user
        naming.save!
        naming
      end

      # Attributed to the reviewer, not the observation's owner: an
      # admin reading someone else's slip is stating their own reading
      # of it, and the vote weight should be theirs to own.
      #
      # `Vote.validate_value` runs `to_f` first, so it answers 0.0 -- not
      # nil -- for a missing or unparseable value. 0 is DELETE_VOTE, and
      # `change_vote` reads it as "remove this vote", so relying on `||`
      # here left a proposed naming with no vote at all: present on the
      # observation, supporting nothing. Treat anything that lands on
      # DELETE_VOTE as absent, since the form's confidence menu never
      # offers it.
      def cast_vote(naming)
        value = Vote.validate_value(@vote)
        value = DEFAULT_VOTE if value.nil? || value == Vote::DELETE_VOTE
        Observation::NamingConsensus.new(@observation).
          change_vote(naming, value, @user)
      end
    end
  end
end
