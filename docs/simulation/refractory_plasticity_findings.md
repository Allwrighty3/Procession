# Refractory motor and plasticity sweep findings

Validated with 100 deterministic seeds, 180 ticks, and environmental reversal at tick 90.

## Profiles

- `current`: decay slowing `0.10`, minimum decay `0.006`
- `moderate`: decay slowing `0.04`, minimum decay `0.025`
- `flexible`: decay slowing `0.00`, minimum decay `0.060`

All profiles use the same channel-specific refractory motor dynamics. Sustained output suppresses its own channel temporarily; no alternative action is selected or rewarded explicitly.

## Results

```text
current: corrected=60 persistent=40 delay=58.000 obsolete=1.000 switches=0.000 entropy=0.210 left_r=1.000 right_r=1.000
moderate: corrected=63 persistent=37 delay=56.000 obsolete=1.000 switches=0.000 entropy=0.210 left_r=1.000 right_r=1.000
flexible: corrected=64 persistent=36 delay=53.500 obsolete=1.000 switches=0.000 entropy=0.210 left_r=1.000 right_r=1.000
```

## Interpretation

Refractory suppression improved correction substantially compared with the prior embodied competition control (`50/100`). It allows an established motor channel to become temporarily unavailable through ordinary sustained use.

Relaxing field cementing also helped, but more modestly:

- current to moderate: `60 -> 63` corrected
- current to flexible: `60 -> 64` corrected
- median correction delay: `58 -> 53.5` ticks

This supports the concern that `decay_slowing: 0.10` and `minimum_decay: 0.006` make paths somewhat more persistent than intended. They are not the sole cause of lock-in, however.

The zero direct-switch count does not mean no redirection occurred. The metric counts only adjacent active-direction changes. Refractory dynamics usually produce `left -> remain -> right`, so redirection is separated by a pause. A future metric should distinguish direct switches from direction changes across inactive intervals.

Final median resistances returned to `1.0` because residue decayed by the end of the run. Correction was detected when right resistance temporarily crossed below left resistance after reversal. This indicates the learned organization remains transient under the more flexible profiles rather than becoming permanently cemented.

## Architectural conclusion

Keep refractory suppression as a promising embodied mechanism. Do not globally adopt the flexible profile yet. The sweep suggests a better default region than the current extremes, likely near the moderate profile, but that should be checked against stable-environment retention so increased reversibility does not erase useful long-term organization too quickly.
