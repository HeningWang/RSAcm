# comprehension_exp

This is the comprehension experiment for the consensus-marker project, built with magpie.
### Setup

First, set up the project with `npm install`

To run the project locally, run `npm run serve`

To build the project for deployment (e.g. to Netlify), run `npm run build`

## Live configuration

The experiment is configured to use the shared live magpie server in:

- [src/magpie.config.js](src/magpie.config.js)

Current defaults:

- live server and websocket endpoint
- `mode: 'directLink'` for a non-debug launch
- real project contact email

When a Prolific study is created, update `completionUrl` and switch `mode` to
`'prolific'`.

## Recorded trial data

Each trial now records analysis-ready metadata, including:

- `list_num`
- `display_order`
- `trial_type` and `is_filler`
- `item_id`, `topic`, `condition_index`
- `pc_prag`, `g_implied`
- `marker` and `marker_assignment_source`
- full stimulus text fields (`context`, `sentence_before`, `sentence_after`, `recommended_action`)
- response fields (`rating_g`, `rating_adopt`, `inferred_goal_strength`, `adoption_likelihood`)
- response scale bounds and reaction time `rt`

This should make the raw export directly usable for comprehension analysis
without reconstructing stimulus metadata later.

If you are hosting this repository on github, the project will automatically be built and deployed to the gh-pages branch, so you only have to enable Github Pages in your repository settings to publish your project.

For more information, see the [manual](https://magpie-experiments.org/).
### Coding style

To automatically fix coding style and format the code (linting) run `npm run lint` and `npm run lint:style`

## How to update magpie

```sh
$ cd your-project
$ npm update magpie-base
```

Read more on [maintaining npm dependencies](https://www.carlrippon.com/upgrading-npm-dependencies/).

