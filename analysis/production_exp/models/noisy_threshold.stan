// models/noisy_threshold.stan
//
// Hierarchical cumulative-probit model for consensus-marker production.
//
// Generative story:
//   For each trial t from participant s:
//     η_t  =  β_pc_prop · pc_prop_t  +  β_pc_prag · pc_prag_t  +  β_g · g_t
//              +  u_s
//
//   Marker choice k is determined by thresholds on a latent continuum:
//     P(Y_t ≤ k)  =  Φ( μ_k  −  η_t )        (cumulative probit)
//     P(Y_t  = k)  =  P(Y_t ≤ k)  −  P(Y_t ≤ k−1)
//
//   Threshold noise (σ_thresh): each threshold μ_k is estimated with
//   uncertainty, i.e., μ_k = μ̃_k + ε_k, ε_k ~ N(0, σ_thresh).
//   In this formulation σ_thresh is folded into the residual variance
//   (standard cumulative probit with unit residual SD).
//
// Parameters:
//   mu[4]          : ordered thresholds  μ_1 < μ_2 < μ_3 < μ_4
//   beta_pc_prop   : effect of perceived consensus (centred norming rating, expected > 0)
//   beta_pc_prag   : effect of pragmatic controversy      (expected < 0)
//   beta_g         : effect of persuasive-goal strength   (expected > 0)
//   u[N_subj]      : by-participant random intercepts
//   sigma_u        : SD of random intercepts
//
// Data format: one row per critical trial (fillers excluded).

data {
  int<lower=1> N;                        // number of critical trials
  int<lower=1> N_subj;                   // number of participants
  array[N] int<lower=1, upper=5> y;      // marker choice (1 = sofern … 5 = bekanntlich)
  vector[N] pc_prop;                     // centred norming rating (SD ≈ 1); higher = more consensus
  vector[N] pc_prag;                     // 0 (low) or 1 (high)
  vector[N] g;                           // 0 (low) or 1 (high)
  array[N] int<lower=1, upper=N_subj> subj; // participant index
}

parameters {
  ordered[4] mu;           // threshold parameters (ordered constraint built-in)
  real beta_pc_prop;
  real beta_pc_prag;
  real beta_g;
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
  u_raw        ~ std_normal();           // non-centred
  sigma_u      ~ exponential(1);

  // -- Likelihood --
  for (n in 1:N) {
    real eta = beta_pc_prop * pc_prop[n] +
               beta_pc_prag * pc_prag[n] +
               beta_g       * g[n]       +
               u[subj[n]];

    // Cumulative probit: P(Y = k | eta) = Phi(mu[k] - eta) - Phi(mu[k-1] - eta)
    vector[5] log_p;
    log_p[1] = log(Phi(mu[1] - eta));
    for (k in 2:4)
      log_p[k] = log(Phi(mu[k] - eta) - Phi(mu[k - 1] - eta));
    log_p[5] = log1m(Phi(mu[4] - eta));

    target += log_p[y[n]];
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

    vector[5] log_p;
    log_p[1] = log(Phi(mu[1] - eta));
    for (k in 2:4)
      log_p[k] = log(Phi(mu[k] - eta) - Phi(mu[k - 1] - eta));
    log_p[5] = log1m(Phi(mu[4] - eta));

    y_rep[n]   = categorical_rng(softmax(log_p));
    log_lik[n] = log_p[y[n]];
  }
}
