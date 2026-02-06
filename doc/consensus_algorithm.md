# How Mushroom Observer Decides on a Name

## Overview

Every observation on Mushroom Observer needs a name. But mushroom
identification is rarely straightforward, and reasonable people often disagree.
To handle this, Mushroom Observer uses a community consensus system: anyone can
propose a name, anyone can vote on it, and the site calculates which name the
community collectively supports.

This article explains how that consensus system works, starting with the
concepts that matter to everyday users and then diving into the technical
details of the algorithm itself.

## The Basics

### Proposing Names and Voting

When you look at an observation, you will see one or more proposed names, each
with a confidence vote. The person who created the observation usually proposes
the first name, but any logged-in member can propose additional names or vote
on existing ones.

When you vote, you choose from a scale that expresses how confident you are
that a particular name applies to the observation:

| Label             | Meaning                                            |
|-------------------|----------------------------------------------------|
| I'd Call It That  | You are confident this is the correct name.        |
| Promising         | You think this name is likely correct.             |
| Could Be          | This name is plausible but you are not sure.       |
| Doubtful          | You have reservations about this name.             |
| Not Likely        | You think this name is probably wrong.             |
| As If!            | You are confident this name is wrong.              |

You can also choose "No Opinion" to remove a previous vote.

The site combines everyone's votes to determine which name "wins." That winning
name becomes the community consensus and is displayed as the observation's name
throughout the site.

### How Votes Are Weighted

Not all votes carry equal weight. The more you contribute to the site (by
adding observations, identifying mushrooms, writing descriptions, etc.), the
more influence your votes have. The observation's owner also gets a small
boost, reflecting the value of having seen the mushroom firsthand. This
weighting is gradual and logarithmic, so casual users still have meaningful
influence, but the collective knowledge of experienced identifiers carries
appropriate weight.

### Synonyms

Mushroom taxonomy is complex. Sometimes two or more names refer to the same
organism but taxonomists disagree on which is correct. Mushroom Observer tracks
these synonyms and groups them together when calculating consensus. If people
vote for different synonyms of the same taxon, those votes are combined. The
currently accepted name in that synonym group is used as the consensus.

## History and Motivation

### The Original Design

The consensus algorithm was designed early in the site's history with a
particular assumption in mind: that most users, when they recognized a mushroom,
would vote "I'd Call It That" (the highest confidence level). Under this model,
a single confident vote would produce a strong consensus, and additional
confident votes would reinforce it.

### How Users Actually Vote

In practice, the community developed a different convention. Many experienced
identifiers routinely vote "Promising" rather than "I'd Call It That." They do
this for two reasons:

1. **Expressing appropriate humility.** Identification from photographs is
   inherently uncertain. Even an expert who is fairly sure of a name may feel
   that "I'd Call It That" overstates the confidence that a photo-based
   identification warrants.

2. **Making it easy for others to override.** A "Promising" vote can be
   outweighed by a single dissenting "I'd Call It That" vote. By voting
   "Promising," an identifier is saying: "I think this is right, but if
   someone more knowledgeable disagrees, I want their opinion to take
   priority."

Importantly, when a user votes "Promising" and has *not* voted "I'd Call It
That" for any other name on the same observation, they are not expressing
actual doubt in the name. They are using "Promising" as their way of saying
"this is my best identification." The doubt implied by a sub-maximum vote only
comes into play when the same user has voted *more* confidently for a
different name.

### The Problem

Under the original algorithm, this widespread use of "Promising" had an
unfortunate side effect: when two people both thought a name was correct and
both voted "Promising," the second vote actually *lowered* the consensus score.
The algorithm treated the second "Promising" vote as if it introduced doubt,
when in reality both voters were expressing agreement.

To understand why, consider the math. With a single "Promising" vote, the
consensus score reflects that one person's moderate confidence. When a second
person adds their own "Promising" vote, the score drops because the algorithm
divides by a larger total weight, diluting the average. The consensus was
designed for a world where agreement meant voting at the maximum level, and
it penalized the community's actual voting convention.

### The Fix

The updated algorithm (Issue #3815) addresses this by recognizing when a
sub-maximum vote represents genuine agreement rather than doubt. When a user's
highest vote across all proposed names is below "I'd Call It That," and the
name they voted on already has a higher vote from someone else, the algorithm
treats their vote as supportive agreement. Their vote now boosts the consensus
rather than diluting it.

The key insight is context. A "Promising" vote on a name where someone else
has already voted "I'd Call It That" is a signal of agreement: "I also think
this is right." But the same "Promising" vote on a name where no one has
voted higher is simply that user's honest assessment. The algorithm now
distinguishes between these two cases.

## Technical Details

The sections below describe the consensus algorithm in detail for developers,
data scientists, and the deeply curious.

### Vote Values and User Weight

Each vote has a numeric value on a scale from -3.0 to 3.0:

| Label            | Value |
|------------------|-------|
| I'd Call It That |   3.0 |
| Promising        |   2.0 |
| Could Be         |   1.0 |
| No Opinion       |   0.0 |
| Doubtful         |  -1.0 |
| Not Likely       |  -2.0 |
| As If!           |  -3.0 |

Each user's vote is weighted by the base-10 logarithm of their contribution
score. The observation owner receives an additional +1 to their weight. Users
with a contribution of 1 or less have zero weight and their votes are ignored.

```
weight = log10(contribution)       # for regular users
weight = log10(contribution) + 1   # for the observation owner
weight = 0                         # if contribution <= 1
```

### Per-Naming Score (vote_cache)

For each proposed name (naming), the algorithm computes a cached score:

```
vote_cache = sum(value_i * weight_i) / (sum(effective_weight_i) + 1.0)
```

The `+1.0` in the denominator is a "prior" that biases the score toward zero
when there are few votes. This ensures that even unanimous agreement never
produces a score equal to the maximum vote value. There is always room for
the consensus to grow with additional votes.

### Effective Weight and the Sub-Max Vote Boost

In the original algorithm, `effective_weight` was always equal to `weight`.
The updated algorithm reduces the effective weight under specific conditions,
which has the effect of boosting the score when sub-maximum votes indicate
agreement.

The boost applies when all four of these conditions are met:

1. The user's highest vote across **all** namings on the observation is
   positive (above zero).
2. That highest vote is **below** "I'd Call It That" (below 3.0).
3. The vote being processed **equals** the user's maximum vote (i.e., this
   is the user's strongest vote, not a weaker secondary vote).
4. The naming already has a **higher vote** from someone else.

When all four conditions hold, the vote is treated as agreement at the
naming's highest level but with reduced weight:

```
effective_weight = (vote_value / naming_max_vote) * weight
```

Where `naming_max_vote` is the highest vote anyone has cast on that naming.

Conceptually, the algorithm elevates the vote's value to the naming's maximum
and reduces the weight proportionally. A "Promising" (2.0) vote on a naming
whose max is "I'd Call It That" (3.0) is treated as a 3.0 vote at 2/3 of the
user's full weight. The numerator contribution is `naming_max * effective_weight`,
which is numerically identical to `vote_value * weight` (since the scaling
factors cancel). The denominator uses the reduced effective weight, making it
smaller and the score larger. The net effect: the sub-maximum vote boosts the
score toward (but never reaching) the naming's maximum vote.

### Why It Works

Consider an example with two users voting on the same naming:

- **User A** votes "I'd Call It That" (3.0) with weight 5.0
- **User B** votes "Promising" (2.0) with weight 4.0, and has not voted
  higher on any other naming

**Old algorithm** (effective_weight = weight for everyone):

```
sum_val = 3.0*5.0 + 2.0*4.0 = 23.0
sum_wgt = 5.0 + 4.0 = 9.0
score   = 23.0 / (9.0 + 1.0) = 2.30
```

Note that User A alone would produce a score of `15.0 / 6.0 = 2.50`. Adding
User B's agreeing vote actually *lowered* the score from 2.50 to 2.30.

**New algorithm** (User B's effective weight = (2.0 / 3.0) * 4.0 = 2.667):

User B's vote is treated as a 3.0 vote at reduced weight:

```
sum_val = 3.0*5.0 + 3.0*2.667 = 23.0
sum_wgt = 5.0 + 2.667 = 7.667
score   = 23.0 / (7.667 + 1.0) = 2.65
```

Now User B's vote raises the score from 2.50 to 2.65 — it boosts the
consensus as intended.

### Mathematical Guarantees

The algorithm maintains two important invariants:

1. **The score never reaches the naming's maximum vote.** Because of the
   `+1.0` prior in the denominator, the score is always strictly less than
   `naming_max * S / (S + 1)` where `S` is the sum of effective weights.
   No amount of agreeing votes can push the consensus to 3.0.

2. **The boost always increases the score.** Reducing the effective weight
   shrinks the denominator without changing the numerator, so the result is
   always larger than it would be with the full weight.

### When the Boost Does Not Apply

The boost is deliberately conservative. It does **not** apply when:

- **The user has voted "I'd Call It That" elsewhere.** If a user voted 3.0 on
  a different naming and 2.0 on this one, the 2.0 genuinely represents less
  confidence in this name. The full weight is used, and the lower vote
  correctly dilutes the consensus.

- **No one has voted higher on this naming.** If "Promising" (2.0) is the
  highest vote on a naming, there is no stronger opinion to agree with. The
  vote is taken at face value.

- **The user's maximum vote is negative.** Negative votes express disagreement.
  The boost only applies to positive sub-maximum votes that represent
  agreement.

### Synonym Handling

When multiple synonyms are proposed for the same observation, the algorithm
first determines the winning **taxon** (synonym group), then picks the best
individual name within that group.

1. **Taxon-level competition.** Votes for all names in a synonym group are
   pooled. Each user's strongest vote within the group represents their
   opinion on the taxon. The taxon with the highest pooled score wins.

2. **Name-level disambiguation.** If the winning taxon has multiple accepted
   names, votes for each individual name are compared to select the best
   one. If none of the accepted names have votes, the algorithm picks the
   first available accepted name.

### Tiebreaking

When two taxa or names have the same weighted score, ties are broken by:

1. **Total weight.** The name with more total vote weight wins.
2. **Age.** The name that was proposed first wins.

### Rollout Strategy

The updated algorithm has been deployed with a conservative rollout approach:

1. **New observations use the updated algorithm immediately.** Any observation
   created or voted on after the update benefits from the improved handling
   of sub-maximum votes.

2. **Existing observations are updated selectively.** For historical
   observations, we only apply the recalculation when the consensus *name*
   would remain unchanged. This updates the `vote_cache` value (the
   confidence score) without changing which name is displayed.

3. **Name changes require human review.** Observations where the new
   algorithm would select a different consensus name are flagged for
   community review rather than being updated automatically. This respects
   the historical record and allows users with relevant knowledge to
   examine these edge cases.

**Why update vote_cache even when the name stays the same?**

The `vote_cache` value represents our confidence in the consensus name.
While it doesn't change which name is displayed, it affects:

- **Ordering on the Show Name page.** Observations are sorted by confidence,
  so more confident identifications appear first.

- **Data exports.** When Mushroom Observer shares data with external systems
  (research databases, biodiversity portals), the confidence score helps
  recipients assess data quality.

- **Needs Naming flag.** Low-confidence observations may be flagged as
  needing additional identification help.

By updating these values, we ensure the confidence scores accurately reflect
community agreement, even for observations where the winning name doesn't
change.

### Implementation Reference

The algorithm is implemented in these files:

- `app/models/observation/consensus_calculator.rb` — Core algorithm
- `app/models/observation/naming_consensus.rb` — Integration with the
  Observation model; handles vote changes and triggers recalculation
- `app/models/vote.rb` — Vote values, labels, and user weight calculation
- `script/analyze_consensus_change.rb` — Migration script for applying
  the update to historical observations
