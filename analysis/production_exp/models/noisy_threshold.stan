// models/noisy_threshold.stan
//
// Hierarchical cumulative-probit model for consensus-marker production.
//
// Generative story:
//   For each trial t from participant s:
//     η_t  =  β_pc_prop · pc_prop_t  +  β_pc_prag · pc_prag_t  +  β_g · g_t
//              +  u_s
//
//   Base marker fit is determined by thresholds on a latent continuum:
//     P_base(Y_t ≤ k)  =  Φ( μ_k  −  η_t )        (cumulative probit)
//     P_base(Y_t  = k) =  P_base(Y_t ≤ k) − P_base(Y_t ≤ k−1)
//
//   Choice additionally includes marker-specific costs:
//     P(Y_t = k) ∝ P_base(Y_t = k) * exp(-cost_k)
//   with cost_1 fixed to 0 for identifiability.
//
//   Threshold noise (σ_thresh): each threshold μ_k is estimated with
//   uncertainty, i.e., μ_k = μ̃_k + ε_k, ε_k ~ N(0, σ_thresh).
//   In this formulation σ_thresh is folded into the residual variance
//   (standard cumulative probit with unit residual SD).
//
// Parameters:
//   mu[2]          : ordered thresholds  μ_1 < μ_2
//   beta_pc_prop   : effect of perceived consensus (centred norming rating, expected > 0)
//   beta_pc_prag   : effect of pragmatic controversy      (expected < 0)
//   beta_g         : effect of persuasive-goal strength   (expected > 0)
//   cost_ja        : markedness / sufficiency cost for ja
//   cost_bek       : markedness / sufficiency cost for bekanntlich
//   u[N_subj]      : by-participant random intercepts
//   sigma_u        : SD of random intercepts
//
// Data format: one row per critical trial (fillers excluded).

data {
  int<lower=1> N;                        // number of critical trials
  int<lower=1> N_subj;                   // number of participants
  array[N] int<lower=1, upper=3> y;      // marker choice (1 = soviel ich weiß … 3 = bekanntlich)
  vector[N] pc_prop;                     // centred norming rating (SD ≈ 1); higher = more consensus
  vector[N] pc_prag;                     // 0 (low) or 1 (high)
  vector[N] g;                           // 0 (low) or 1 (high)
  array[N] int<lower=1, upper=N_subj> subj; // participant index
}

parameters {
  ordered[2] mu;           // threshold parameters (ordered constraint built-in)
  real beta_pc_prop;
  real beta_pc_prag;
  real beta_g;
  real<lower=0> cost_ja;
  real<lower=0> cost_bek;
  vector[N_subj] u_raw;   // non-centred parameterisation
  real<lower=0> sigma_u;
}

transformed parameters {
  vector[N_subj] u = u_raw * sigma_u;
}

model {
  // -- Priors --
  mu           ~ normal(0, 2);           // weakly informative; ordered by constraint
  beta_pc_prop ~ normal( 1, 1);          // expected positive (more consensus → stronger marker)
  beta_pc_prag ~ normal(-1, 1);
  beta_g       ~ normal( 1, 1);          // expected positive
  cost_ja      ~ exponential(1.5);
  cost_bek     ~ exponential(1.5);
  u_raw        ~ std_normal();           // non-centred
  sigma_u      ~ exponential(1);

  // -- Likelihood --
  for (n in 1:N) {
    real eta = beta_pc_prop * pc_prop[n] +
               beta_pc_prag * pc_prag[n] +
               beta_g       * g[n]       +
               u[subj[n]];

    vector[3] log_w;
    real p1 = fmax(Phi(mu[1] - eta), 1e-12);
    real p2 = fmax(Phi(mu[2] - eta) - Phi(mu[1] - eta), 1e-12);
    real p3 = fmax(1 - Phi(mu[2] - eta), 1e-12);
    log_w[1] = log(p1);
    log_w[2] = log(p2) - cost_ja;
    log_w[3] = log(p3) - cost_bek;

    target += categorical_logit_lpmf(y[n] | log_w);
  }
}

generated quantities {
  // Posterior predictive: sample marker for each observation
  array[N] int y_rep;
  // Marginal log-likelihood per observation (for LOO-CV)
  vector[N] log_lik;

  for (n in 1:N) {
    real eta = beta_pc_prop * pc_prop[n] +
               beta_pc_prag * pc_prag[n] +
               beta_g       * g[n]       +
               u[subj[n]];

    vector[3] log_w;
    real p1 = fmax(Phi(mu[1] - eta), 1e-12);
    real p2 = fmax(Phi(mu[2] - eta) - Phi(mu[1] - eta), 1e-12);
    real p3 = fmax(1 - Phi(mu[2] - eta), 1e-12);
    log_w[1] = log(p1);
    log_w[2] = log(p2) - cost_ja;
    log_w[3] = log(p3) - cost_bek;

    y_rep[n]   = categorical_logit_rng(log_w);
    log_lik[n] = categorical_logit_lpmf(y[n] | log_w);
  }
}
