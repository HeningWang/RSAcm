library(shiny)
library(ggplot2)
library(dplyr)
library(tidyr)

theme_model_base <- function() {
  theme_minimal(base_size = 14) +
    theme(
      panel.grid.minor = element_blank(),
      plot.title.position = "plot"
    )
}

# ══════════════════════════════════════════════════════════════════════════════
# MODEL FUNCTIONS
# ══════════════════════════════════════════════════════════════════════════════

PC <- function(pc_prop, pc_prag) pc_prop * pc_prag

U <- function(pc, g, w_pc = 1, w_g = 1, w_int = 0.8) {
  -w_pc * pc + w_g * g - w_int * pc * g
}

choice_prob_matrix <- function(util, thr, uthr, sig, usig, lambda, costs) {
  weights <- vapply(seq_along(thr), function(i) {
    interval_lik(util, thr[i], sig[i], uthr[i], usig[i], lambda) * exp(-costs[i])
  }, numeric(length(util)))
  row_sums <- rowSums(weights)
  bad <- !is.finite(row_sums) | row_sums <= 0
  row_sums[bad] <- 1
  probs <- sweep(weights, 1, row_sums, "/")
  if (any(bad)) probs[bad, ] <- 1 / ncol(probs)
  probs
}

# Noisy-threshold interval likelihood (Option A)
#
# Thresholds are treated as random variables: theta_i ~ N(mu_i, sigma_i^2).
# Because theta_i and theta_{i+1} are independent, the expectation factorises:
#
#   E[P(u_i | pc, g)] = E_{theta_i}[sigma(lambda*(U-theta_i))]
#                     * E_{theta_{i+1}}[sigma(-lambda*(U-theta_{i+1}))]
#
# Each factor is a logistic-normal integral, approximated via the probit link:
#   E_{t~N(mu,sig^2)}[sigma(a*(U-t))]
#     ≈ Phi( a*(U-mu)*c / sqrt(1 + (a*sig*c)^2) ),  c = sqrt(pi/8)
#
# When sigma -> 0 this recovers a step-function (hard) interval.
# The approximation error is < 0.01 across the parameter range of interest.

PROBIT_C <- sqrt(pi / 8)   # ≈ 0.6267

interval_lik <- function(util, mu_lo, sig_lo, mu_hi, sig_hi, lambda) {
  lo_z <- lambda * (util - mu_lo) * PROBIT_C /
    sqrt(1 + (lambda * sig_lo * PROBIT_C)^2)
  lo   <- pnorm(lo_z)
  if (is.finite(mu_hi)) {
    hi_z <- -lambda * (util - mu_hi) * PROBIT_C /
      sqrt(1 + (lambda * sig_hi * PROBIT_C)^2)
    hi   <- pnorm(hi_z)
  } else {
    hi <- 1
  }
  lo * hi
}

##################################################
## CSP-colors
##################################################
CSP_colors <- c(
  "#7581B3", "#99C2C2", "#C65353", "#E2BA78", "#5C7457", "#575463",
  "#B0B7D4", "#66A3A3", "#DB9494", "#D49735", "#9BB096", "#D4D3D9",
  "#414C76", "#993333"
)

scale_colour_discrete <- function(...) {
  scale_colour_manual(..., values = CSP_colors)
}
scale_fill_discrete <- function(...) {
  scale_fill_manual(..., values = CSP_colors)
}

# Assign CSP colors to markers in order
marker_names <- c(
  "soviel ich weiß",
  "ja",
  "bekanntlich"
)
marker_colors <- setNames(CSP_colors[seq_along(marker_names)], marker_names)

# ══════════════════════════════════════════════════════════════════════════════
# UI
# ══════════════════════════════════════════════════════════════════════════════

ui <- fluidPage(
  tags$head(tags$style(HTML("
    @import url('https://fonts.googleapis.com/css2?family=IBM+Plex+Mono:wght@400;600&family=IBM+Plex+Sans:wght@300;400;600&display=swap');
    body{background:#0d0f14;color:#c8d0e0;font-family:'IBM Plex Sans',sans-serif;font-size:14px;}
    h2{font-family:'IBM Plex Mono',monospace;font-size:1.1rem;color:#7eb8f7;letter-spacing:.08em;text-transform:uppercase;margin-bottom:4px;}
    h4{font-family:'IBM Plex Mono',monospace;font-size:.78rem;color:#5a6a80;letter-spacing:.12em;text-transform:uppercase;margin-bottom:12px;}
    .well,.panel{background:#161a22!important;border:1px solid #232b38!important;border-radius:6px!important;}
    .shiny-input-container label{color:#7eb8f7;font-size:12px;font-family:'IBM Plex Mono',monospace;letter-spacing:.05em;}
    .irs--shiny .irs-bar{background:#3b6fcc;}
    .irs--shiny .irs-single{background:#3b6fcc;font-size:11px;}
    .irs--shiny .irs-handle{border-color:#7eb8f7;background:#1e2533;}
    .irs--shiny .irs-line{background:#232b38;}
    .nav-tabs>li>a{color:#7eb8f7!important;background:#161a22!important;border-color:#232b38!important;font-family:'IBM Plex Mono',monospace;font-size:12px;}
    .nav-tabs>li.active>a{background:#232b38!important;color:#fff!important;}
    .tab-content{background:#161a22;border:1px solid #232b38;border-top:none;padding:16px;border-radius:0 0 6px 6px;}
    .stat-box{background:#1a1f2b;border:1px solid #2a3448;border-radius:5px;padding:12px 16px;margin-bottom:10px;font-family:'IBM Plex Mono',monospace;}
    .stat-label{color:#5a6a80;font-size:11px;letter-spacing:.1em;text-transform:uppercase;}
    .stat-value{color:#7eb8f7;font-size:1.5rem;font-weight:600;}
    .pred-box{background:#0f1520;border-left:3px solid #3b6fcc;padding:10px 14px;margin-bottom:8px;border-radius:0 4px 4px 0;font-size:13px;line-height:1.6;}
    .pred-label{font-family:'IBM Plex Mono',monospace;font-size:10px;color:#3b6fcc;letter-spacing:.15em;text-transform:uppercase;margin-bottom:4px;}
    hr{border-color:#232b38;}
    select.form-control{background:#1a1f2b;color:#c8d0e0;border:1px solid #2a3448;}
  "))),
  
  fluidRow(column(12, div(style="padding:20px 10px 8px 10px;",
                          h2("Consensus Marker Model Explorer"),
                          h4("Qualitative predictions — cost-augmented noisy-threshold model")
  ))),
  
  fluidRow(
    # ── Sidebar ────────────────────────────────────────────────────────────
    column(3,
           wellPanel(
             tags$b(style="font-family:'IBM Plex Mono',monospace;font-size:12px;color:#7eb8f7;letter-spacing:.1em;", "MODEL PARAMETERS"),
             hr(),
             sliderInput("lambda", "Sensitivity λ", min=0.5, max=20, value=6,   step=0.5),
             sliderInput("w_pc",   "Weight w_pc",   min=0.1, max=3,  value=1,   step=0.1),
             sliderInput("w_g",    "Weight w_g",    min=0.1, max=3,  value=1,   step=0.1),
             sliderInput("w_int",  "Interaction w_int", min=0, max=3, value=0.8, step=0.1),
             hr(),
             tags$b(style="font-family:'IBM Plex Mono',monospace;font-size:12px;color:#7eb8f7;letter-spacing:.1em;", "MARKER COSTS"),
             helpText(style="color:#5a6a80;font-size:11px;", "Higher costs penalize stronger or more marked choices, allowing weaker markers to block stronger ones when they already do enough."),
             sliderInput("cost_soviel",      "Cost soviel ich weiß",     min=0, max=3, value=0.0, step=0.05),
             sliderInput("cost_ja",          "Cost ja",                  min=0, max=3, value=0.35, step=0.05),
             sliderInput("cost_bekanntlich", "Cost bekanntlich",         min=0, max=3, value=0.6, step=0.05),
             hr(),
             tags$b(style="font-family:'IBM Plex Mono',monospace;font-size:12px;color:#7eb8f7;letter-spacing:.1em;", "ADOPTION PARAMETERS"),
             sliderInput("eta_0",  "η₀ (intercept)", min=-2, max=2, value=0, step=0.1),
             sliderInput("eta_g",  "η_g",            min=0,  max=5, value=2, step=0.1),
             sliderInput("eta_pc", "η_pc",           min=0,  max=5, value=2, step=0.1),
             hr(),
             tags$b(style="font-family:'IBM Plex Mono',monospace;font-size:12px;color:#7eb8f7;letter-spacing:.1em;", "MARKER THRESHOLDS"),
             helpText(style="color:#5a6a80;font-size:11px;", "Must be ordered: soviel < ja < bekanntlich"),
             sliderInput("th_soviel",     "soviel ich weiß", min=-3, max=3, value=-0.6, step=0.1),
             sliderInput("th_ja",         "ja",              min=-3, max=3, value= 0.05, step=0.1),
             sliderInput("th_bekanntlich","bekanntlich",     min=-3, max=3, value= 0.55, step=0.05),
             hr(),
             tags$b(style="font-family:'IBM Plex Mono',monospace;font-size:12px;color:#7eb8f7;letter-spacing:.1em;", "THRESHOLD NOISE (σ)"),
             helpText(style="color:#5a6a80;font-size:11px;", "σ=0 → hard boundary. Increase to model overlapping markers."),
             sliderInput("sig_soviel",     "σ soviel ich weiß", min=0, max=1, value=0.1, step=0.05),
             sliderInput("sig_ja",         "σ ja",              min=0, max=1, value=0.15, step=0.05),
             sliderInput("sig_bekanntlich","σ bekanntlich",     min=0, max=1, value=0.1,  step=0.05),
             hr(),
             sliderInput("n_grid", "Grid points per dim", min=15, max=50, value=35, step=5)
           )
    ),
    
    # ── Main panel ─────────────────────────────────────────────────────────
    column(9,
           tabsetPanel(
             
             # ── Tab 1: Across markers ──────────────────────────────────────────
             tabPanel("Posterior Summaries",
                      br(),
                      div(class="pred-box",
                         "Stronger markers still tend to license lower expected controversy E[pc∣u] and higher persuasive goal strength E[g∣u], but marker costs can block unnecessarily strong choices.",
                          tags$br(),
                         "This creates a weakest-sufficient bias: if a weaker marker already does the job, the speaker need not go all in with the strongest one."
                      ),
                      fluidRow(
                        column(4, plotOutput("plot_Epc",   height=270)),
                        column(4, plotOutput("plot_Eg",    height=270)),
                        column(4, plotOutput("plot_adopt", height=270))
                      ),
                      fluidRow(
                        column(4, downloadButton("dl_pc",    "↓ pc_given_u.png",    style="width:100%")),
                        column(4, downloadButton("dl_g",     "↓ g_given_u.png",     style="width:100%")),
                        column(4, downloadButton("dl_adopt", "↓ adopt_given_u.png", style="width:100%"))
                      ),
                      fluidRow(
                        column(4, div(class="stat-box",
                                      div(class="stat-label", "E[pc | bekanntlich]"),
                                      div(class="stat-value", textOutput("stat_pc_bek"))
                        )),
                        column(4, div(class="stat-box",
                                      div(class="stat-label", "E[g | bekanntlich]"),
                                      div(class="stat-value", textOutput("stat_g_bek"))
                        )),
                        column(4, div(class="stat-box",
                                      div(class="stat-label", "P(Adopt | bekanntlich)"),
                                      div(class="stat-value", textOutput("stat_adopt_bek"))
                        ))
                      )
             ),
             
             # ── Tab 2: Decomposition ───────────────────────────────────────────
             tabPanel("Propositional vs. Pragmatic",
                      br(),
                      div(class="pred-box",
                          "Perceived controversy pc = pc_prop × pc_prag can be decomposed: high propositional controversy (pc_prop) is compensated by low pragmatic controversy (pc_prag) and vice versa.",
                          tags$br(),
                          "Stronger markers push posterior mass toward low pc_prop (the product can be high only if pc_prag remains elevated)."
                      ),
                      fluidRow(
                        column(3, selectInput("marker_decomp1", "Left marker",
                                              choices=marker_names, selected="soviel ich weiß")),
                        column(3, selectInput("marker_decomp2", "Right marker",
                                              choices=marker_names, selected="bekanntlich"))
                      ),
                      fluidRow(
                        column(6, plotOutput("plot_decomp1", height=340)),
                        column(6, plotOutput("plot_decomp2", height=340))
                      ),
                      fluidRow(
                        column(6, downloadButton("dl_decomp1", "↓ int_pc_prop_pc_prag_weak.png",   style="width:100%")),
                        column(6, downloadButton("dl_decomp2", "↓ int_pc_prop_pc_prag_strong.png", style="width:100%"))
                      )
             ),
             
             # ── Tab 3: Interaction ─────────────────────────────────────────────
             tabPanel("Super-additivity",
                      br(),
                      div(class="pred-box",
                         "Super-additivity: as pragmatic controversy (pc_prag) increases, the gap in E[g∣u] between strong and weak markers widens.",
                          tags$br(),
                         "But with non-zero marker costs, strong markers can still be disfavoured when a weaker option is already sufficient for the speaker's purpose."
                      ),
                      fluidRow(
                        column(4, sliderInput("pc_prop_fixed", "Fix pc_prop at:",
                                              min=0.1, max=0.9, value=0.5, step=0.1))
                      ),
                      plotOutput("plot_interaction", height=400),
                      br(),
                      downloadButton("dl_interaction", "↓ int_pc_marker_g.png")
             ),
             
             # ── Tab 4: Utility landscape ───────────────────────────────────────
             tabPanel("Utility Landscape",
                      br(),
                      div(class="pred-box",
                         "Base utility U(pc, g) = −w_pc·pc + w_g·g − w_int·(pc·g) is combined with marker-specific costs c_u.",
                         tags$br(),
                         "Choice weights are proportional to interval fit × exp(−c_u), so stronger markers can be blocked when they are unnecessarily costly."
                      ),
                      plotOutput("plot_utility", height=480),
                      br(),
                      downloadButton("dl_utility", "↓ util_landscape.png")
             ),
             
             # ── Tab 5: Scalar implicature ──────────────────────────────────────
             tabPanel("Scalar Implicature",
                      br(),
                      div(class="pred-box",
                         "Using a weaker marker implicates either that the context did not support a stronger marker enough, or that the stronger option was not worth its extra cost.",
                          tags$br(),
                         "The posterior over utility U∣u should still concentrate in the licensed interval [μ_i, μ_{i+1}), but costs compress the top end by favoring weaker sufficient competitors."
                      ),
                      plotOutput("plot_scalar", height=460),
                      br(),
                      downloadButton("dl_scalar", "↓ scalar_implicature.png")
             ),
             
             # ── Tab 6: Infelicity ──────────────────────────────────────────────
             tabPanel("Infelicity",
                      br(),
                      div(class="pred-box",
                         "A marker is infelicitous when its cost-adjusted choice probability is much lower than that of the best competitor in the same context.",
                          tags$br(),
                         "Infelicity score = log P(u_best | pc, g) − log P(u | pc, g): how much worse the chosen marker is versus the optimal one.",
                          tags$br(),
                         "Costs add another source of oddness: an over-strong marker can sound excessive even in favorable contexts if a cheaper weaker marker would already suffice."
                      ),
                      fluidRow(
                        column(4, sliderInput("g_infel", "Fix g at:", min=0.1, max=0.9, value=0.7, step=0.1))
                      ),
                      plotOutput("plot_infel", height=420),
                      br(),
                      downloadButton("dl_infel", "↓ infelicity.png")
             ),

             # ── Tab 7: Sufficiency blocking ─────────────────────────────────────
             tabPanel("Sufficiency Blocking",
                      br(),
                      div(class="pred-box",
                          "New prediction: in low-controversy contexts, a strong marker can be blocked even under high speaker goal if a weaker marker is already sufficient.",
                          tags$br(),
                          "The line plot compares direct speaker choice probabilities across goal strength g at fixed controversy pc. Red shading marks regions where bekanntlich would win without marker costs but is blocked once costs are included.",
                          tags$br(),
                          "The heatmap below shows the full pc × g region where this overkill effect appears."
                      ),
                      fluidRow(
                        column(4, sliderInput("pc_block", "Fix overall controversy pc at:",
                                              min=0.01, max=0.99, value=0.15, step=0.01)),
                        column(8, div(class="stat-box",
                                       div(class="stat-label", "Blocking summary"),
                                       div(style="font-size:13px;line-height:1.5;", textOutput("block_summary"))
                        ))
                      ),
                      plotOutput("plot_block", height=430),
                      br(),
                      downloadButton("dl_block", "↓ sufficiency_blocking.png"),
                      br(), br(),
                      plotOutput("plot_block_map", height=430),
                      br(),
                      downloadButton("dl_block_map", "↓ sufficiency_blocking_map.png")
             ),
             
             # ── Tab 8: Credibility discounting ────────────────────────────────
             tabPanel("Credibility Discounting",
                      br(),
                      div(class="pred-box",
                          "A sceptical listener has an independent belief about how controversial the topic is (pc_prior), separate from the marker's signal.",
                          tags$br(),
                          "E[g\u2223u] stays monotonically ordered with marker strength regardless of pc_prior — the marker reliably signals the speaker's goal.",
                          tags$br(),
                          "But P(Adopt\u2223u, pc_prior) converges as pc_prior rises: the controversy penalty erodes the advantage of strong markers.",
                          tags$br(),
                            "The discounting effect: the gap P(Adopt\u2223bekanntlich) \u2212 P(Adopt\u2223soviel ich weiß) shrinks toward zero at high pc_prior and high \u03b7_pc."
                      ),
                      fluidRow(
                        column(3, sliderInput("eta_g2",    "\u03b7_g (goal weight)",           min=0, max=8, value=2,   step=0.1)),
                        column(3, sliderInput("eta_pc2",   "\u03b7_pc (controversy penalty)",  min=0, max=8, value=2,   step=0.1)),
                        column(3, sliderInput("eta_int2",  "\u03b7_int (g\u00d7pc interaction, enables reversal)",
                                              min=0, max=8, value=0, step=0.1)),
                        column(3, sliderInput("eta_02",    "\u03b7_0 (intercept)",             min=-2, max=2, value=0,  step=0.1))
                      ),
                      fluidRow(
                        column(3, sliderInput("disc_lam",  "Sharpness of pc_prior",           min=1,  max=30, value=1, step=1,
                                              helpText("1 = flat prior; higher = listener more certain about pc_prior")))
                      ),
                      plotOutput("plot_disc", height=460),
                      br(),
                      downloadButton("dl_disc", "\u2193 credibility_discounting.png")
             )
           )
    )
  )
)

# ══════════════════════════════════════════════════════════════════════════════
# SERVER
# ══════════════════════════════════════════════════════════════════════════════

server <- function(input, output, session) {
  
  # ── Reactive thresholds (ordered) ────────────────────────────────────────
  thresholds_r <- reactive({
    c(
      "soviel ich weiß" = input$th_soviel,
      "ja"              = input$th_ja,
      "bekanntlich"     = input$th_bekanntlich
    )
  })
  
  upper_thresholds_r <- reactive({
    thr <- thresholds_r()
    c(thr[-1], Inf)
  })
  
  sigmas_r <- reactive({
    c(
      "soviel ich weiß" = input$sig_soviel,
      "ja"              = input$sig_ja,
      "bekanntlich"     = input$sig_bekanntlich
    )
  })
  
  upper_sigmas_r <- reactive({
    sig <- sigmas_r()
    c(sig[-1], 0)   # sigma for the upper boundary of each marker
  })

  costs_r <- reactive({
    c(
      "soviel ich weiß" = input$cost_soviel,
      "ja"              = input$cost_ja,
      "bekanntlich"     = input$cost_bekanntlich
    )
  })
  
  # ── Shared 3D base grid ───────────────────────────────────────────────────
  base_grid_r <- reactive({
    n <- input$n_grid
    g <- expand.grid(
      pc_prop = seq(0.01, 0.99, length.out=n),
      pc_prag = seq(0.01, 0.99, length.out=n),
      g       = seq(0.01, 0.99, length.out=n)
    )
    g$pc   <- PC(g$pc_prop, g$pc_prag)
    g$util <- U(g$pc, g$g, input$w_pc, input$w_g, input$w_int)
    g
  })
  
  # ── Posterior for one marker ──────────────────────────────────────────────
  posterior_for <- function(grid, idx) {
    probs <- choice_prob_matrix(
      grid$util,
      thresholds_r(), upper_thresholds_r(),
      sigmas_r(), upper_sigmas_r(),
      input$lambda,
      costs_r()
    )
    lik <- probs[, idx]
    s   <- sum(lik)
    if (s == 0 || !is.finite(s)) return(rep(1/nrow(grid), nrow(grid)))
    lik / s
  }
  
  # ── Theme ───────────────────────────────────────────────────
  theme_set(theme_model_base())
  theme_model <- function() {
    theme_model_base() +
      theme(
        axis.text.y  = element_text(size = 14),
        axis.text.x  = element_text(size = 14),
        axis.title.y = element_text(size = 16),
        axis.title.x = element_text(size = 16),
        legend.text  = element_text(size = 14),
        legend.title = element_text(size = 14)
      )
  }
  
  # ── Tab 1: summaries ──────────────────────────────────────────────────────
  summaries_r <- reactive({
    thr  <- thresholds_r()
    uthr <- upper_thresholds_r()
    sig  <- sigmas_r()
    usig <- upper_sigmas_r()
    grid <- base_grid_r()
    
    lapply(seq_along(thr), function(i) {
      post        <- posterior_for(grid, i)
      Epc         <- sum(grid$pc * post)
      Eg          <- sum(grid$g  * post)
      logit_adopt <- input$eta_0 + input$eta_g * grid$g - input$eta_pc * grid$pc
      P_adopt     <- sum((1/(1+exp(-logit_adopt))) * post)
      data.frame(marker=names(thr)[i], Epc=Epc, Eg=Eg, P_adopt=P_adopt,
                 stringsAsFactors=FALSE)
    }) |> do.call(what=rbind)
  })
  
  build_bar <- function(yvar, ylab) {
    reactive({
      df <- summaries_r()
      df$marker <- factor(df$marker, levels=names(thresholds_r()))
      ggplot(df, aes(x=marker, y=.data[[yvar]], fill=marker)) +
        geom_col(width=0.6, alpha=0.9) +
        scale_fill_manual(values=marker_colors, guide="none") +
        scale_x_discrete(labels=function(x) gsub(" ", "\n", x)) +
        labs(x=NULL, y=ylab) +
        theme_model()
    })
  }
  
  plot_Epc_r   <- build_bar("Epc",     "E[pc | u]")
  plot_Eg_r    <- build_bar("Eg",      "E[g | u]")
  plot_adopt_r <- build_bar("P_adopt", "P(Adopt | u)")
  
  output$plot_Epc   <- renderPlot({ plot_Epc_r()   })
  output$plot_Eg    <- renderPlot({ plot_Eg_r()    })
  output$plot_adopt <- renderPlot({ plot_adopt_r() })
  
  dl_handler <- function(plot_r, filename, w=7, h=5) {
    downloadHandler(
      filename = filename,
      content  = function(file) {
        ggsave(file, plot=plot_r(), width=w, height=h, dpi=150, bg="white")
      }
    )
  }
  
  output$dl_pc    <- dl_handler(plot_Epc_r,   "pc_given_u.png")
  output$dl_g     <- dl_handler(plot_Eg_r,    "g_given_u.png")
  output$dl_adopt <- dl_handler(plot_adopt_r, "adopt_given_u.png")
  
  output$stat_pc_bek    <- renderText(sprintf("%.3f", summaries_r()$Epc[summaries_r()$marker=="bekanntlich"]))
  output$stat_g_bek     <- renderText(sprintf("%.3f", summaries_r()$Eg[summaries_r()$marker=="bekanntlich"]))
  output$stat_adopt_bek <- renderText(sprintf("%.3f", summaries_r()$P_adopt[summaries_r()$marker=="bekanntlich"]))
  
  # ── Tab 2: decomposition heatmaps ────────────────────────────────────────
  decomp_df <- function(u) {
    thr  <- thresholds_r()
    uthr <- upper_thresholds_r()
    sig  <- sigmas_r()
    usig <- upper_sigmas_r()
    idx  <- which(names(thr) == u)
    
    n      <- max(input$n_grid, 30)
    g_vals <- seq(0.01, 0.99, length.out=25)
    
    grid2d <- expand.grid(
      pc_prop = seq(0.01, 0.99, length.out=n),
      pc_prag = seq(0.01, 0.99, length.out=n)
    )
    
    grid2d$post_marg <- apply(grid2d, 1, function(row) {
      pc   <- PC(row["pc_prop"], row["pc_prag"])
      util <- U(pc, g_vals, input$w_pc, input$w_g, input$w_int)
      probs <- choice_prob_matrix(util, thr, uthr, sig, usig, input$lambda, costs_r())
      mean(probs[, idx])
    })
    s <- sum(grid2d$post_marg)
    if (s > 0) grid2d$post_marg <- grid2d$post_marg / s
    grid2d
  }
  
  make_heatmap <- function(u) {
    df <- decomp_df(u)
    # Square-root transform to pull up low-density regions
    df$post_sqrt <- sqrt(df$post_marg)
    # Sort for correct raster/contour rendering
    df <- df[order(df$pc_prag, df$pc_prop), ]
    ggplot(df, aes(pc_prop, pc_prag)) +
      geom_raster(aes(fill=post_sqrt), interpolate=TRUE) +
      scale_fill_gradientn(
        colours = c("#f7f7f7", "#d9d9d9", colorRampPalette(
          c("#d9d9d9", marker_colors[u]))(8)),
        name    = "Posterior density",
        guide   = guide_colourbar(barwidth=0.8, barheight=8)
      ) +
      geom_contour(data=df, aes(x=pc_prop, y=pc_prag, z=post_marg),
                   colour="grey30", alpha=0.6, linewidth=0.4,
                   bins=6, inherit.aes=FALSE) +
      labs(x="Propositional controversy (pc_prop)", y="Pragmatic controversy (pc_prag)") +
      coord_fixed() +
      theme_model() +
      theme(legend.position="right")
  }
  
  plot_decomp1_r <- reactive({ make_heatmap(input$marker_decomp1) })
  plot_decomp2_r <- reactive({ make_heatmap(input$marker_decomp2) })
  
  output$plot_decomp1 <- renderPlot({ plot_decomp1_r() })
  output$plot_decomp2 <- renderPlot({ plot_decomp2_r() })
  
  output$dl_decomp1 <- dl_handler(plot_decomp1_r, "int_pc_prop_pc_prag_weak.png",   w=7, h=6)
  output$dl_decomp2 <- dl_handler(plot_decomp2_r, "int_pc_prop_pc_prag_strong.png", w=7, h=6)
  
  # ── Tab 3: interaction ────────────────────────────────────────────────────
  plot_interaction_r <- reactive({
    thr          <- thresholds_r()
    uthr         <- upper_thresholds_r()
    sig          <- sigmas_r()
    usig         <- upper_sigmas_r()
    pc_prop_val  <- input$pc_prop_fixed
    pc_prag_vals <- seq(0.05, 0.95, by=0.05)
    g_vals       <- seq(0.01, 0.99, length.out=35)
    markers_sel  <- names(thr)
    
    rows <- lapply(markers_sel, function(u) {
      idx    <- which(names(thr) == u)
      lapply(pc_prag_vals, function(pc_prag) {
        pc   <- PC(pc_prop_val, pc_prag)
        util <- U(pc, g_vals, input$w_pc, input$w_g, input$w_int)
        probs <- choice_prob_matrix(util, thr, uthr, sig, usig, input$lambda, costs_r())
        lik  <- probs[, idx]
        s    <- sum(lik)
        post <- if (s > 0) lik/s else rep(1/length(g_vals), length(g_vals))
        data.frame(marker=u, pc_prag=pc_prag, Eg=sum(g_vals * post))
      }) |> do.call(what=rbind)
    }) |> do.call(what=rbind)
    
    rows$marker <- factor(rows$marker, levels=names(thr))
    ggplot(rows, aes(pc_prag, Eg, color=marker, group=marker)) +
      geom_line(linewidth=1.4) +
      scale_color_manual(values=marker_colors, name="Marker") +
      labs(x="Pragmatic controversy (pc_prag)", y="E[g | u]") +
      theme_model()
  })
  
  output$plot_interaction <- renderPlot({ plot_interaction_r() })
  output$dl_interaction   <- dl_handler(plot_interaction_r, "int_pc_marker_g.png", w=10, h=5)
  
  # ── Tab 4: utility landscape ──────────────────────────────────────────────
  plot_utility_r <- reactive({
    thr  <- thresholds_r()
    uthr <- upper_thresholds_r()
    sig  <- sigmas_r()
    usig <- upper_sigmas_r()
    
    # Best response under the cost-augmented noisy-threshold choice rule.
    n    <- 800L
    grid <- expand.grid(pc=seq(0, 1, length.out=n), g=seq(0, 1, length.out=n))
    grid$U <- U(grid$pc, grid$g, input$w_pc, input$w_g, input$w_int)
    probs <- choice_prob_matrix(grid$U, thr, uthr, sig, usig, input$lambda, costs_r())
    grid$best_idx    <- max.col(probs, ties.method = "first")
    grid$best_marker <- factor(names(thr)[grid$best_idx], levels=names(thr))
    
    # Mean threshold lines only (no ±sigma bands — they cross regions and cause visual noise)
    pc_seq <- seq(0, 1, length.out=600)
    denom  <- input$w_g - input$w_int * pc_seq
    
    # For each threshold i: mean line + ribbon between (mu_i - sigma_i) and (mu_i + sigma_i)
    # The ribbon is grey/white to show the fuzzy overlap zone without coloured crossing lines
    thresh_list <- lapply(seq_along(thr), function(i) {
      mu  <- unname(thr[i])
      s   <- unname(sig[i])
      # mean line
      g_mean <- (mu + input$w_pc * pc_seq) / denom
      # ±sigma bounds (not clipped yet — ribbon handles that via ymin/ymax)
      g_lo   <- (mu - s + input$w_pc * pc_seq) / denom
      g_hi   <- (mu + s + input$w_pc * pc_seq) / denom
      ok_mean <- denom > 0.01 & g_mean >= 0 & g_mean <= 1
      ok_band <- denom > 0.01 & !(g_lo > 1 | g_hi < 0)  # band intersects [0,1]
      list(
        mean = if (sum(ok_mean) >= 2)
          data.frame(pc=pc_seq[ok_mean], g=g_mean[ok_mean],
                     marker=names(thr)[i], stringsAsFactors=FALSE)
        else NULL,
        band = if (sum(ok_band) >= 2)
          data.frame(pc    = pc_seq[ok_band],
                     g_lo  = pmax(0, g_lo[ok_band]),
                     g_hi  = pmin(1, g_hi[ok_band]),
                     marker= names(thr)[i], stringsAsFactors=FALSE)
        else NULL
      )
    })
    
    thresh_df <- do.call(rbind, lapply(thresh_list, `[[`, "mean"))
    thresh_df$marker <- factor(thresh_df$marker, levels=names(thr))
    
    band_df <- do.call(rbind, lapply(thresh_list, `[[`, "band"))
    band_df$marker <- factor(band_df$marker, levels=names(thr))
    
    ggplot(grid, aes(x=pc, y=g)) +
      geom_raster(aes(fill=best_marker)) +
      scale_fill_manual(values=marker_colors, name="Licensed marker") +
      # uncertainty band: semi-transparent white ribbon around each threshold
      geom_ribbon(data=band_df,
                  aes(x=pc, ymin=g_lo, ymax=g_hi, group=marker),
                  fill="white", alpha=0.35, inherit.aes=FALSE) +
      # mean threshold lines in matching marker colour
      geom_line(data=thresh_df,
                aes(x=pc, y=g, colour=marker),
                linewidth=1.1, inherit.aes=FALSE) +
      # ±sigma dashed lines
      geom_line(data=band_df,
                aes(x=pc, y=g_lo, colour=marker),
                linewidth=0.5, linetype="dashed", inherit.aes=FALSE) +
      geom_line(data=band_df,
                aes(x=pc, y=g_hi, colour=marker),
                linewidth=0.5, linetype="dashed", inherit.aes=FALSE) +
      scale_colour_manual(values=marker_colors, guide="none") +
      scale_x_continuous(expand=c(0,0)) +
      scale_y_continuous(expand=c(0,0)) +
      labs(x="Overall perceived controversy (pc)",
           y="Persuasive goal strength (g)") +
      theme_model() +
      theme(plot.margin = margin(5, 30, 5, 5, "mm"))
  })
  
  output$plot_utility <- renderPlot({ plot_utility_r() })
  output$dl_utility   <- dl_handler(plot_utility_r, "util_landscape.png", w=11, h=6)
  
  # ── Tab 5: Scalar implicature ─────────────────────────────────────────────────
  # P(U | u_i) should concentrate in [mu_i, mu_{i+1}).
  # Background rect = licensed interval; grey bands = ±sigma overlap zones.
  plot_scalar_r <- reactive({
    thr  <- thresholds_r()
    uthr <- upper_thresholds_r()
    sig  <- sigmas_r()
    usig <- upper_sigmas_r()
    grid <- base_grid_r()
    
    u_breaks <- seq(-1.5, 1.5, length.out=100)
    u_mids   <- 0.5 * (u_breaks[-1] + u_breaks[-length(u_breaks)])
    
    dens_df <- do.call(rbind, lapply(seq_along(thr), function(i) {
      post <- posterior_for(grid, i)
      bin  <- findInterval(grid$util, u_breaks)
      bin  <- pmax(1L, pmin(length(u_mids), bin))
      mass <- tapply(post, bin, sum)
      full_mass <- rep(0, length(u_mids))
      full_mass[as.integer(names(mass))] <- as.numeric(mass)
      data.frame(
        U       = u_mids,
        density = full_mass / (u_breaks[2] - u_breaks[1]),
        marker  = names(thr)[i],
        stringsAsFactors = FALSE
      )
    }))
    dens_df$marker <- factor(dens_df$marker, levels=names(thr))
    
    # Licensed interval background rect: [mu_i, mu_{i+1})
    rect_df <- data.frame(
      xmin   = unname(thr),
      xmax   = ifelse(is.finite(unname(uthr)), unname(uthr), 1.5),
      marker = names(thr),
      stringsAsFactors = FALSE
    )
    rect_df$marker <- factor(rect_df$marker, levels=names(thr))
    
    # ±sigma overlap bands around lower threshold (shows where adjacent markers blur)
    lo_band_df <- data.frame(
      xmin   = unname(thr) - unname(sig),
      xmax   = unname(thr) + unname(sig),
      marker = names(thr),
      stringsAsFactors = FALSE
    )
    lo_band_df$marker <- factor(lo_band_df$marker, levels=names(thr))
    
    # ±sigma overlap band around upper threshold
    hi_band_df <- data.frame(
      xmin   = ifelse(is.finite(unname(uthr)), unname(uthr) - unname(usig), NA_real_),
      xmax   = ifelse(is.finite(unname(uthr)), unname(uthr) + unname(usig), NA_real_),
      marker = names(thr),
      stringsAsFactors = FALSE
    )
    hi_band_df <- hi_band_df[!is.na(hi_band_df$xmin), ]
    hi_band_df$marker <- factor(hi_band_df$marker, levels=names(thr))
    
    # Marker label with line breaks for strip
    marker_labels <- setNames(
      gsub(" ", "
", names(thr)),
      names(thr)
    )
    
    ggplot(dens_df, aes(x=U, y=density)) +
      # Licensed interval shaded background
      geom_rect(data=rect_df,
                aes(xmin=xmin, xmax=xmax, ymin=-Inf, ymax=Inf, fill=marker),
                alpha=0.12, inherit.aes=FALSE) +
      # ±sigma overlap zones at lower boundary (grey)
      geom_rect(data=lo_band_df,
                aes(xmin=xmin, xmax=xmax, ymin=-Inf, ymax=Inf),
                fill="grey50", alpha=0.20, inherit.aes=FALSE) +
      # ±sigma overlap zones at upper boundary (grey)
      geom_rect(data=hi_band_df,
                aes(xmin=xmin, xmax=xmax, ymin=-Inf, ymax=Inf),
                fill="grey50", alpha=0.20, inherit.aes=FALSE) +
      # Solid vertical line = lower threshold mu_i (licensed from here)
      geom_vline(data=rect_df,
                 aes(xintercept=xmin, colour=marker),
                 linewidth=0.9, linetype="solid", inherit.aes=FALSE) +
      # Dashed vertical line = upper threshold mu_{i+1} (implicated upper bound)
      geom_vline(data=rect_df,
                 aes(xintercept=xmax, colour=marker),
                 linewidth=0.7, linetype="dashed", inherit.aes=FALSE) +
      # Posterior density
      geom_area(aes(colour=marker, fill=marker), alpha=0.35, linewidth=1.0) +
      scale_colour_manual(values=marker_colors) +
      scale_fill_manual(values=marker_colors) +
      facet_wrap(~marker, ncol=1, strip.position="right",
                 labeller=labeller(marker=marker_labels)) +
      labs(x="Utility U(pc, g)", y="Posterior density") +
      theme_model() +
      theme(
        legend.position  = "none",
        strip.text       = element_text(size=11, lineheight=0.85),
        strip.background = element_rect(fill="grey92", colour=NA),
        panel.spacing    = unit(0.6, "lines")
      )
  })
  
  output$plot_scalar <- renderPlot({ plot_scalar_r() })
  output$dl_scalar   <- dl_handler(plot_scalar_r, "scalar_implicature.png", w=8, h=9)
  
  # ── Tab 6: Infelicity ────────────────────────────────────────────────────────
  # Infelicity score at each pc value (with g fixed) for a chosen marker vs best.
  # Score = log P(u_best | pc, g) - log P(u_chosen | pc, g).
  # High score = context is a poor fit for the chosen marker after threshold fit
  # and marker costs are combined.
  plot_infel_r <- reactive({
    thr  <- thresholds_r()
    uthr <- upper_thresholds_r()
    sig  <- sigmas_r()
    usig <- upper_sigmas_r()
    g_val <- input$g_infel
    
    pc_seq <- seq(0.01, 0.99, length.out=200)
    util   <- U(pc_seq, g_val, input$w_pc, input$w_g, input$w_int)
    
    probs <- choice_prob_matrix(util, thr, uthr, sig, usig, input$lambda, costs_r())
    log_lik_mat <- log(pmax(probs, 1e-12))
    
    # Best marker log-lik per pc point
    log_lik_best <- apply(log_lik_mat, 1, max)
    
    # Infelicity scores for ALL markers
    all_scores <- do.call(rbind, lapply(seq_along(thr), function(i) {
      data.frame(pc=pc_seq,
                 score=log_lik_best - log_lik_mat[, i],
                 marker=names(thr)[i], stringsAsFactors=FALSE)
    }))
    all_scores$marker <- factor(all_scores$marker, levels=names(thr))
    
    ggplot(all_scores, aes(x=pc, y=score, colour=marker)) +
      geom_line(linewidth=1.4) +
      geom_hline(yintercept=0, linetype="dotted", colour="grey50") +
      scale_colour_manual(values=marker_colors, name="Marker") +
      labs(x="Overall perceived controversy (pc)",
           y="Infelicity score (log-likelihood gap)") +
      theme_model() +
      theme(
        legend.position   = "top",
        legend.box.margin = margin(0, 0, 2, 0, "mm"),
        plot.margin       = margin(5, 5, 5, 5, "mm")
      ) +
      guides(colour = guide_legend(nrow = 1))
  })
  
  output$plot_infel <- renderPlot({ plot_infel_r() })
  output$dl_infel   <- dl_handler(plot_infel_r, "infelicity.png", w=12, h=6)

  # ── Tab 7: sufficiency blocking ───────────────────────────────────────────
  blocking_df_r <- reactive({
    thr   <- thresholds_r()
    uthr  <- upper_thresholds_r()
    sig   <- sigmas_r()
    usig  <- upper_sigmas_r()
    costs <- costs_r()

    g_seq <- seq(0.01, 0.99, length.out = 250)
    util  <- U(input$pc_block, g_seq, input$w_pc, input$w_g, input$w_int)

    probs_cost <- choice_prob_matrix(util, thr, uthr, sig, usig, input$lambda, costs)
    probs_base <- choice_prob_matrix(util, thr, uthr, sig, usig, input$lambda,
                                     rep(0, length(costs)))

    out <- do.call(rbind, lapply(seq_along(thr), function(i) {
      data.frame(
        g = g_seq,
        marker = names(thr)[i],
        prob = probs_cost[, i],
        prob_nocost = probs_base[, i],
        stringsAsFactors = FALSE
      )
    }))

    out$marker <- factor(out$marker, levels = names(thr))
    out$best_cost <- names(thr)[max.col(probs_cost, ties.method = "first")][match(out$g, g_seq)]
    out$best_nocost <- names(thr)[max.col(probs_base, ties.method = "first")][match(out$g, g_seq)]
    out$bek_blocked <- out$best_nocost == "bekanntlich" & out$best_cost != "bekanntlich"
    out
  })

  plot_block_r <- reactive({
    df <- blocking_df_r()
    shade_df <- df |>
      dplyr::group_by(g) |>
      dplyr::summarise(bek_blocked = any(bek_blocked), .groups = "drop") |>
      dplyr::filter(bek_blocked)

    p <- ggplot(df, aes(x = g, y = prob, colour = marker))

    if (nrow(shade_df) > 0) {
      p <- p + geom_rect(
        data = data.frame(
          xmin = min(shade_df$g),
          xmax = max(shade_df$g),
          ymin = -Inf,
          ymax = Inf
        ),
        aes(xmin = xmin, xmax = xmax, ymin = ymin, ymax = ymax),
        inherit.aes = FALSE,
        fill = "#C65353",
        alpha = 0.10
      )
    }

    p +
      geom_line(linewidth = 1.4) +
      scale_colour_manual(values = marker_colors, name = "Marker") +
      scale_y_continuous(limits = c(0, 1), labels = scales::percent_format()) +
      labs(
        x = "Speaker goal strength (g)",
        y = "Speaker choice probability",
        title = "Weakest-sufficient prediction at fixed controversy",
        subtitle = paste0("pc = ", sprintf("%.2f", input$pc_block),
                          "; shading = bekanntlich blocked by a cheaper competitor")
      ) +
      theme_model() +
      theme(legend.position = "top")
  })

  output$plot_block <- renderPlot({ plot_block_r() })
  output$dl_block   <- dl_handler(plot_block_r, "sufficiency_blocking.png", w=10, h=6)

  plot_block_map_r <- reactive({
    thr   <- thresholds_r()
    uthr  <- upper_thresholds_r()
    sig   <- sigmas_r()
    usig  <- upper_sigmas_r()
    costs <- costs_r()

    n_pc <- 160L
    n_g  <- 160L
    grid <- expand.grid(
      pc = seq(0.01, 0.99, length.out = n_pc),
      g  = seq(0.01, 0.99, length.out = n_g)
    )
    util <- U(grid$pc, grid$g, input$w_pc, input$w_g, input$w_int)

    probs_cost <- choice_prob_matrix(util, thr, uthr, sig, usig, input$lambda, costs)
    probs_base <- choice_prob_matrix(util, thr, uthr, sig, usig, input$lambda,
                                     rep(0, length(costs)))

    best_cost   <- names(thr)[max.col(probs_cost, ties.method = "first")]
    best_nocost <- names(thr)[max.col(probs_base, ties.method = "first")]

    grid$blocked <- best_nocost == "bekanntlich" & best_cost != "bekanntlich"
    grid$winner  <- factor(best_cost, levels = names(thr))

    ggplot(grid, aes(x = pc, y = g)) +
      geom_raster(aes(fill = winner)) +
      geom_raster(data = grid[grid$blocked, , drop = FALSE],
                  aes(x = pc, y = g),
                  inherit.aes = FALSE,
                  fill = "#C65353", alpha = 0.45) +
      scale_fill_manual(values = marker_colors, name = "Cost-sensitive\nwinner") +
      labs(
        x = "Overall perceived controversy (pc)",
        y = "Speaker goal strength (g)",
        title = "Where the strongest marker is blocked",
        subtitle = "Red overlay: bekanntlich would win without costs, but a weaker marker wins once costs are added"
      ) +
      theme_model() +
      theme(legend.position = "right")
  })

  output$plot_block_map <- renderPlot({ plot_block_map_r() })
  output$dl_block_map   <- dl_handler(plot_block_map_r, "sufficiency_blocking_map.png", w=10, h=6)

  output$block_summary <- renderText({
    df <- blocking_df_r() |>
      dplyr::group_by(g) |>
      dplyr::summarise(
        best_cost = dplyr::first(best_cost),
        best_nocost = dplyr::first(best_nocost),
        bek_blocked = dplyr::first(bek_blocked),
        .groups = "drop"
      )

    blocked <- df[df$bek_blocked, , drop = FALSE]
    if (nrow(blocked) == 0) {
      paste0(
        "At pc = ", sprintf("%.2f", input$pc_block),
        ", bekanntlich is not currently blocked. Raise its cost or lower controversy further to produce the overkill pattern."
      )
    } else {
      paste0(
        "At pc = ", sprintf("%.2f", input$pc_block),
        ", bekanntlich would be the best no-cost marker for approximately g ∈ [",
        sprintf("%.2f", min(blocked$g)), ", ", sprintf("%.2f", max(blocked$g)),
        "] but is blocked once costs are added. In that region, a weaker marker is predicted to be sufficient."
      )
    }
  })
  
  # ── Tab 8: Credibility discounting ──────────────────────────────────────────
  # The listener has a private prior over pc (pc_prior) independent of the marker.
  # We compute E[g|u, pc_prior] and P(Adopt|u, pc_prior) by marginalising over g
  # only, with pc fixed at pc_prior (listener treats pc as known).
  # Plot shows both quantities as lines over pc_prior ∈ [0,1] for all markers.
  # E[g|u] stays ordered; P(Adopt) lines converge/cross at high pc_prior+η_pc.
  plot_disc_r <- reactive({
    thr  <- thresholds_r()
    uthr <- upper_thresholds_r()
    sig  <- sigmas_r()
    usig <- upper_sigmas_r()
    lam  <- input$lambda
    
    pc_seq <- seq(0.02, 0.98, length.out=60)
    g_vals <- seq(0.01, 0.99, length.out=80)
    
    rows <- do.call(rbind, lapply(seq_along(thr), function(i) {
      do.call(rbind, lapply(pc_seq, function(pc_prior) {
        util <- U(pc_prior, g_vals, input$w_pc, input$w_g, input$w_int)
        probs <- choice_prob_matrix(util, thr, uthr, sig, usig, lam, costs_r())
        l    <- probs[, i]
        extra_w <- if (input$disc_lam > 1) {
          mu_centre <- (unname(thr[i]) + ifelse(is.finite(unname(uthr[i])), unname(uthr[i]), unname(thr[i]) + 1)) / 2
          exp(-(input$disc_lam - 1) * (util - mu_centre)^2 / 2)
        } else rep(1, length(g_vals))
        post <- l * extra_w
        s    <- sum(post)
        post <- if (s > 0) post/s else rep(1/length(g_vals), length(g_vals))
        
        Eg <- sum(g_vals * post)
        # Adoption: interaction term -eta_int2*g*pc_prior penalises high persuasive
        # intent when controversy is known to be high — enabling reversal of ordering
        logit   <- input$eta_02 + input$eta_g2 * g_vals -
          input$eta_pc2 * pc_prior -
          input$eta_int2 * g_vals * pc_prior
        P_adopt <- sum((1 / (1 + exp(-logit))) * post)
        
        data.frame(marker   = names(thr)[i],
                   pc_prior = pc_prior,
                   Eg       = Eg,
                   P_adopt  = P_adopt,
                   stringsAsFactors = FALSE)
      }))
    }))
    
    rows$marker <- factor(rows$marker, levels = names(thr))
    
    # Convert to long format for facet_wrap (avoids patchwork dependency)
    long <- rbind(
      data.frame(rows[, c("marker", "pc_prior")],
                 value   = rows$Eg,
                 measure = "E[g | u, pc_prior]",
                 stringsAsFactors = FALSE),
      data.frame(rows[, c("marker", "pc_prior")],
                 value   = rows$P_adopt,
                 measure = "P(Adopt | u, pc_prior)",
                 stringsAsFactors = FALSE)
    )
    long$measure <- factor(long$measure,
                           levels = c("E[g | u, pc_prior]", "P(Adopt | u, pc_prior)"))
    
    ggplot(long, aes(x = pc_prior, y = value, colour = marker, group = marker)) +
      geom_line(linewidth = 1.2) +
      facet_wrap(~ measure, ncol = 1, scales = "free_y") +
      scale_colour_manual(values = marker_colors, name = "Marker") +
      labs(x = "Listener's prior on controversy (pc_prior)", y = NULL) +
      theme_model() +
      theme(
        legend.position = "top",
        strip.text      = element_text(size = 13, face = "bold")
      ) +
      guides(colour = guide_legend(nrow = 1))
  })
  
  output$plot_disc       <- renderPlot({ plot_disc_r() })
  output$dl_disc         <- dl_handler(plot_disc_r, "credibility_discounting.png", w=8, h=8)
}

shinyApp(ui, server)