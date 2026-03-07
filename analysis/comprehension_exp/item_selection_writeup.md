# Comprehension item-selection write-up

## 1. Preregistered procedure

The preregistration states that the marker shown in each comprehension critical
trial should be determined by the fitted production model. Concretely, for each
of the 32 critical cells (8 items × 4 conditions), we compute the posterior
predictive distribution $P(\text{marker} \mid pc_{\text{prop}}, pc_{\text{prag}}, g)$
from the fitted production model and assign the modal marker to that cell.

This confirmatory, preregistered assignment is implemented in:

- [analysis/comprehension_exp/01_item_selection_from_production.R](analysis/comprehension_exp/01_item_selection_from_production.R)

Outputs:

- [analysis/comprehension_exp/data/comprehension_marker_assignment_matrix.csv](analysis/comprehension_exp/data/comprehension_marker_assignment_matrix.csv)
- [experiments/item/comprehension_marker_assignment.csv](experiments/item/comprehension_marker_assignment.csv)

## 2. Empirical problem with the strict preregistered rule

Applying the strict modal rule to the current fitted production model yields a
highly imbalanced comprehension stimulus set:

- `bekanntlich`: 27 of 32 cells
- `ja`: 5 of 32 cells
- `soviel ich weiß`: 0 of 32 cells

In addition, many modal decisions are weak. Several cells have only tiny gaps
between the best and second-best marker probabilities, meaning the strict modal
rule collapses substantial uncertainty into a single deterministic choice.

This creates a design problem for the comprehension experiment: listener-side
marker effects would be tested with very little actual marker diversity.

## 3. Exploratory balancing procedure

To preserve meaningful variation in the comprehension materials, an exploratory,
uncertainty-aware balancing procedure was added.

This procedure is implemented in:

- [analysis/comprehension_exp/02_balanced_item_selection.R](analysis/comprehension_exp/02_balanced_item_selection.R)

### Rule

1. Start from the posterior predicted marker probabilities for all 32 critical
   item × condition cells.
2. Consider near-balanced marker count targets across the 32 cells:
   - 10 / 11 / 11
   - 11 / 10 / 11
   - 11 / 11 / 10
3. For each target, find the assignment that maximizes the total log posterior
   support:

$$
\sum_{c=1}^{32} \log P(m_c \mid \text{cell}_c)
$$

subject to the chosen count constraint.
4. Select the target/assignment combination with the highest total posterior
   support.

### Rationale

This balancing step is **not** the preregistered confirmatory assignment rule.
It is an exploratory design-optimization step intended to produce a usable
comprehension stimulus set while staying as faithful as possible to the fitted
production model.

The optimization is conservative in the sense that it still prefers markers with
higher posterior support; it does not assign labels arbitrarily.

## 4. Outputs of the exploratory balancing step

- [analysis/comprehension_exp/data/comprehension_balanced_assignment_matrix.csv](analysis/comprehension_exp/data/comprehension_balanced_assignment_matrix.csv)
- [analysis/comprehension_exp/data/comprehension_balanced_assignment_long.csv](analysis/comprehension_exp/data/comprehension_balanced_assignment_long.csv)
- [analysis/comprehension_exp/data/comprehension_balanced_assignment_summary.csv](analysis/comprehension_exp/data/comprehension_balanced_assignment_summary.csv)
- [experiments/item/comprehension_marker_assignment_balanced.csv](experiments/item/comprehension_marker_assignment_balanced.csv)
- [analysis/comprehension_exp/data/comprehension_balanced_prediction_table.md](analysis/comprehension_exp/data/comprehension_balanced_prediction_table.md)
- [analysis/comprehension_exp/plots/fig_balanced_assignment_predictions.png](analysis/comprehension_exp/plots/fig_balanced_assignment_predictions.png)

### What the balanced assignment predicts

Under the balanced assignment, the marker counts are:

- `soviel ich weiß`: 10 cells
- `ja`: 11 cells
- `bekanntlich`: 11 cells

Average posterior support for the selected marker is still moderate:

- mean selected probability: 0.392
- mean modal probability under the strict rule: 0.442
- cells deviating from the strict modal assignment: 21 of 32

The balanced design preserves a strong asymmetry across conditions rather than
flattening the model predictions completely:

- low pragmatic controversy + high goal: 8/8 cells assigned `bekanntlich`
- low pragmatic controversy + low goal: 5 `soviel ich weiß`, 3 `ja`, 0 `bekanntlich`
- high pragmatic controversy + low goal: 3 `soviel ich weiß`, 5 `ja`, 0 `bekanntlich`
- high pragmatic controversy + high goal: 3 `soviel ich weiß`, 2 `ja`, 3 `bekanntlich`

So the balanced assignment keeps the clearest model-based prediction intact in
the low-pragmatic-controversy / high-goal cells, where `bekanntlich` remains
strongly favored, while redistributing the more weakly separated cells to
recover usable marker diversity elsewhere in the design.

## 5. Recommended reporting practice

For transparency, both outputs should be retained:

- the preregistered modal assignment as the confirmatory production-to-
  comprehension mapping
- the balanced assignment as an exploratory material-selection deviation used to
  ensure sufficient marker diversity in the comprehension study

If the balanced assignment is used for actual data collection, this should be
reported explicitly as a deviation from the preregistered selection rule.

## 6. Suggested methods-deviation paragraph

The preregistration specified that the comprehension stimuli would be generated
by assigning, for each critical item × condition cell, the modal marker from
the fitted production model. Applying this rule to the current production fit
yielded a highly imbalanced stimulus set, with the vast majority of cells
assigned to *bekanntlich* and almost no variation across marker categories.
Because this would have substantially reduced the informativeness of the
comprehension experiment for testing marker-based listener inferences, we
implemented an exploratory balancing step for stimulus construction. Starting
from the posterior predictive marker probabilities for all 32 critical cells,
we selected a near-balanced assignment of the three markers that maximized total
posterior support subject to balanced marker counts across the design. We retain
the strict preregistered modal assignment as the confirmatory production-to-
comprehension mapping, but use the balanced assignment as a transparent,
documented deviation for stimulus generation in the comprehension experiment.

### Short version

The preregistered item-selection rule assigned the modal marker from the fitted
production model to each comprehension cell. Because this yielded an extremely
imbalanced stimulus set, we introduced a documented exploratory balancing step:
markers were reassigned across cells to obtain a near-balanced design while
maximizing posterior support under the fitted production model. The original
modal assignment is retained as the preregistered baseline, and the balanced
assignment is reported as a deviation used for stimulus construction.
