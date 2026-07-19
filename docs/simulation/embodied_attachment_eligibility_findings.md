# Embodied Attachment Eligibility Findings

## Question

Can decaying sensory-motor eligibility traces bridge the delay between movement toward a caregiver and later bodily regulation, allowing proximity-seeking to emerge without a follow-parent force?

## Change

The embodied attachment experiment now gives the child a decaying `eligibility` map keyed by caregiver-cue bucket and motor direction.

A movement becomes eligible only when it increases the locally perceived caregiver cue. Eligibility decays independently of long-term cue memory. Later bodily relief can reinforce any still-active eligible traces.

The child still has no:

- parent direction input,
- separation-distance motor pressure,
- hunger-to-resource direction mapping,
- survival objective,
- causal label identifying caregiver relief.

## Controls

The existing 20-seed, 1,800-tick comparison remains unchanged:

1. regulating caregiver: warmth, provisioning, and recovery on contact;
2. visible but non-regulating caregiver: identical moving cue, no bodily regulation;
3. no parent: no caregiver cue or care.

## Result

```text
regulated:   survived=0/20 lifetime=983 memory=0 eligibility=0 intake=0 visits=0
unregulated: survived=0/20 lifetime=105 memory=0 eligibility=0 intake=0 visits=0
no_parent:   survived=0/20 lifetime=105 memory=0 eligibility=0 intake=0 visits=0
```

Eligibility traces did not produce learned attachment. Final eligibility and cue memory remained empty in all three conditions.

## Interpretation

The temporal-credit mechanism exists, but the organism never supplies it with a usable sequence. Weak exploratory movement does not reliably produce a cue-increasing movement that remains eligible until later caregiver contact. The caregiver's route and the child's motor-development timescale are mismatched.

The result therefore does not show that eligibility traces are ineffective. It shows that delayed reinforcement cannot bootstrap learning when the organism rarely generates eligible approach behavior in the first place.

The next controlled question should be whether changing only temporal scale—slower caregiver movement or longer-lived eligibility—allows regulation to reinforce approach traces without introducing directional attraction.
