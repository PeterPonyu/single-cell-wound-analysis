#!/usr/bin/env Rscript
# Rendering only: completed JSON reports -> R/grid -> editable TikZ.
# All dimensions below are millimetres at the final 180 mm journal width.
suppressPackageStartupMessages({
  library(ggplot2)
  library(grid)
  library(jsonlite)
  library(tikzDevice)
})
script <- sub("^--file=", "", grep("^--file=", commandArgs(), value = TRUE)[1])
ROOT <- normalizePath(file.path(dirname(script), "../.."))
OUT <- file.path(ROOT, "manuscripts/figures")
TEX <- file.path(OUT, "tex")
DATA <- file.path(OUT, "source_data")
BUILD <- file.path(ROOT, "outputs/figure_r_tikz")
for (d in c(TEX, DATA, BUILD)) dir.create(d, recursive = TRUE, showWarnings = FALSE)
requested <- commandArgs(trailingOnly = TRUE)

NAVY <- "#234E70"; BLUE <- "#4C78A8"; TEAL <- "#1F8A8A"
GREEN <- "#2E7D32"; ORANGE <- "#C46A1B"; PURPLE <- "#6B4C9A"
RED <- "#B44B4B"; GRAY <- "#73777B"; DARK <- "#263238"
ARMS <- c("Healer" = GREEN, "Non-healer" = ORANGE, "Healthy" = PURPLE)
font_commands <- c("\\usepackage{fontspec}", "\\setmainfont{Arial}", "\\setsansfont{Arial}")
options(tikzDefaultEngine = "xetex",
        tikzUnicodeMetricPackages = c(font_commands, "\\usetikzlibrary{calc}"),
        tikzMetricPackages = c(font_commands, "\\usetikzlibrary{calc}"),
        tikzMetricsDictionary = file.path(BUILD, "arial-metrics"))

theme_set(theme_classic(base_size = 8, base_family = "Arial") + theme(
  # Figure lettering is deliberately monochrome and bold. Data marks and
  # reference lines retain colour; every textual element remains black.
  text = element_text(colour = "black", face = "bold"),
  axis.text = element_text(size = 7.5, colour = "black", face = "bold"),
  axis.title.x = element_text(size = 8, colour = "black", face = "bold", margin = margin(t = 1.4, unit = "mm")),
  axis.title.y = element_text(size = 8, colour = "black", face = "bold", margin = margin(r = 1.3, unit = "mm")),
  axis.ticks = element_line(linewidth = 0.25, colour = GRAY),
  axis.ticks.length = unit(1, "mm"),
  axis.line = element_line(linewidth = 0.25, colour = GRAY),
  panel.grid.major.y = element_line(linewidth = 0.18, colour = "#E2E7EB"),
  panel.grid.minor = element_blank(),
  plot.margin = margin(t = 1.8, r = 1.2, b = 1.2, l = 1.2, unit = "mm"),
  plot.background = element_rect(fill = "white", colour = NA),
  legend.position = "bottom",
  legend.text = element_text(size = 7, colour = "black", face = "bold"),
  legend.title = element_blank(),
  legend.key.size = unit(3.2, "mm"), legend.spacing.x = unit(1.2, "mm"),
  legend.margin = margin(0, 0, 0, 0, unit = "mm"),
  legend.box.spacing = unit(1.3, "mm")
))
sources <- list(); active_sources <- character(); figures <- list()
read_report <- function(path) {
  full <- file.path(ROOT, path)
  d <- fromJSON(full, simplifyVector = FALSE)
  if (identical(d$status, "failed")) stop("Failed source: ", path)
  sources[[path]] <<- digest::digest(file = full, algo = "sha256")
  active_sources <<- unique(c(active_sources, path))
  d
}
repaired <- function(name) read_report(paste0("outputs/analysis/", name, "/report.json"))
historical <- function(name) read_report(paste0("outputs/", name, "/report.json"))
num <- function(rows, key) vapply(rows, function(x) as.numeric(x[[key]]), numeric(1))
chr <- function(rows, key) vapply(rows, function(x) as.character(x[[key]]), character(1))
vector <- function(x) as.numeric(unlist(x, use.names = FALSE))
ordered_factor <- function(x) factor(x, levels = unique(x))
panel <- function(plot, title, data) list(plot = plot, title = title, data = data)
zero_h <- function() geom_hline(yintercept = 0, colour = GRAY, linewidth = .25)
zero_v <- function(x = 0) geom_vline(xintercept = x, colour = GRAY, linewidth = .3, linetype = "dashed")
xgrid <- function() theme(panel.grid.major.y = element_blank(),
                         panel.grid.major.x = element_line(linewidth = .18, colour = "#E2E7EB"))
columns <- function(d, ylabel, colors, limits = NULL) {
  d$label <- ordered_factor(d$label)
  p <- ggplot(d, aes(label, value, fill = label)) +
    geom_col(width = .58) + scale_fill_manual(values = colors) +
    labs(x = NULL, y = ylabel) + theme(legend.position = "none")
  if (!is.null(limits)) p <- p + coord_cartesian(ylim = limits)
  p
}
forest <- function(d, xlabel = "AUC", ref = .5, limits = c(0, 1)) {
  d$label <- factor(d$label, levels = rev(unique(d$label)))
  ggplot(d, aes(value, label)) + zero_v(ref) +
    geom_errorbar(aes(xmin = low, xmax = high), orientation = "y", width = .15,
                  colour = NAVY, linewidth = .55) +
    geom_point(size = 2, colour = NAVY) +
    scale_x_continuous(limits = limits, expand = expansion(mult = .025)) +
    labs(x = xlabel, y = NULL) + xgrid()
}
record_figure <- function(name, width, height, panels) {
  data_files <- character()
  for (i in seq_along(panels)) {
    path <- file.path(DATA, paste0(name, "_", LETTERS[i], ".csv"))
    write.csv(panels[[i]]$data, path, row.names = FALSE, na = "")
    data_files <- c(data_files, sub(paste0(ROOT, "/"), "", path, fixed = TRUE))
  }
  figures[[name]] <<- list(width_mm = width, height_mm = height,
      panels = vapply(panels, `[[`, character(1), "title"),
      sources = active_sources, data = data_files)
  active_sources <<- character()
  message("TikZ: ", name)
}
draw_figure <- function(name, panels, height = 82, widths = NULL, nrow = 1, gap = 5) {
  ncol <- length(panels) / nrow
  stopifnot(ncol == as.integer(ncol))
  width <- 180; left <- 3; top <- 2; bottom <- 1.5; row_gap <- 4
  if (is.null(widths)) widths <- rep((width - 2 * left - gap * (ncol - 1)) / ncol, ncol)
  stopifnot(abs(sum(widths) + gap * (ncol - 1) - 174) < .01)
  row_h <- (height - top - bottom - row_gap * (nrow - 1)) / nrow
  tikz(file.path(TEX, paste0(name, ".tex")), width = width / 25.4, height = height / 25.4,
       pointsize = 8, standAlone = TRUE, engine = "xetex", sanitize = TRUE,
       timestamp = FALSE, documentDeclaration = "\\documentclass[10pt]{standalone}",
       packages = c("\\usepackage{tikz}", font_commands))
  on.exit(dev.off())
  grid.newpage()
  for (i in seq_along(panels)) {
    col <- (i - 1) %% ncol + 1; row <- (i - 1) %/% ncol + 1
    x <- left + sum(head(widths, col - 1)) + gap * (col - 1)
    y <- height - top - (row - 1) * (row_h + row_gap)
    # Letter, title and plotting region use three separate physical slots.
    grid.text(LETTERS[i], unit(x, "mm"), unit(y, "mm"), just = c("left", "top"),
              gp = gpar(fontfamily = "Arial", fontsize = 11, fontface = "bold", col = "black"))
    grid.text(panels[[i]]$title, unit(x, "mm"), unit(y - 4.5, "mm"), just = c("left", "top"),
              gp = gpar(fontfamily = "Arial", fontsize = 9, fontface = "bold", col = "black"))
    pushViewport(viewport(x = unit(x, "mm"), y = unit(y - 8.7, "mm"),
                          width = unit(widths[col], "mm"), height = unit(row_h - 8.7, "mm"),
                          just = c("left", "top"), clip = "off"))
    grid.draw(ggplotGrob(panels[[i]]$plot))
    popViewport()
  }
  record_figure(name, width, height, panels)
}
write_workflow <- function(name, height, body, steps) {
  colors <- paste0("\\definecolor{", c("navy", "blue", "teal", "orange", "purple", "green", "gray"),
                   "}{HTML}{", sub("#", "", c(NAVY, BLUE, TEAL, ORANGE, PURPLE, GREEN, GRAY)), "}")
  lines <- c("\\documentclass[10pt]{standalone}", "\\usepackage{tikz}", font_commands,
    "\\usetikzlibrary{arrows.meta,patterns}", colors, "\\begin{document}",
    "\\begin{tikzpicture}[x=1mm,y=1mm,font=\\fontsize{8}{10}\\selectfont\\bfseries,text=black,>=Latex]",
    sprintf("\\path[use as bounding box] (0,0) rectangle (180,%s);", height),
    "\\tikzset{step/.style={draw=#1!40,fill=#1!8,rounded corners=1mm,",
    "minimum height=13mm,text width=21mm,align=center,inner sep=1.5mm,text=black},",
    "link/.style={->,draw=gray,line width=0.45pt}}", body,
    "\\end{tikzpicture}", "\\end{document}")
  writeLines(lines, file.path(TEX, paste0(name, ".tex")))
  record_figure(name, 180, height, list(panel(NULL, "Study design", data.frame(step = steps))))
}
methods <- c("topic_simplex_theta0", "module_score", "pca", "nmf")
method_names <- c("Fibroblast\ntopic", "Module", "PCA", "NMF")

paper1_figure1_workflow <- function() {
  body <- readLines(file.path(ROOT, "manuscripts/r_tikz/construct_design.tikz"))
  write_workflow("paper1_figure1_workflow", 106, body,
    c("Data and distinct readouts", "Conceptual abundance comparison", "Technical, patient and external evidence"))
}
sample_data <- function(d) data.frame(sample = chr(d, "gsm"),
    arm = factor(c("DFU-healer" = "Healer", "DFU-nonhealer" = "Non-healer", "Non-diabetic" = "Healthy")[chr(d, "arm")], levels = names(ARMS)),
    mean = num(d, "topic0_mean"), weight = num(d, "mixing_weight"))
paper1_figure2_mixture_semantics <- function() {
  d <- historical("bimodal_stratification")$cohorts$GSE165816_discovery
  s <- repaired("mixture_semantic_inference")
  a <- sample_data(d$per_sample)
  pa <- ggplot(a, aes(weight, mean, colour = arm, shape = arm)) +
    geom_point(size = 1.9, alpha = .9) + scale_colour_manual(values = ARMS) +
    scale_shape_manual(values = c(16, 17, 15)) +
    scale_x_continuous(breaks = c(0, .4, .8)) +
    labs(x = "High-state fraction", y = "Mean fibroblast-topic loading") +
    guides(colour = guide_legend(nrow = 2, byrow = TRUE), shape = guide_legend(nrow = 2, byrow = TRUE))
  b <- data.frame(label = c("Pure\nlow", "Mixed", "Other", "Pure\nhigh"),
      value = vector(d$hypotheses$shape_counts[c("pure_low", "mixed", "other", "pure_high")]))
  pb <- columns(b, "Samples", c("#BCC7CF", BLUE, GRAY, PURPLE), c(0, 18)) +
    scale_y_continuous(breaks = c(0, 5, 10, 15))
  c <- data.frame(label = c("Bootstrap", "Leave-one-out"),
    value = c(s$observed$spearman_rho, NA),
    low = c(s$bootstrap$ci95[[1]], s$leave_one_sample_out$rho_min),
    high = c(s$bootstrap$ci95[[2]], s$leave_one_sample_out$rho_max))
  c$label <- factor(c$label, levels = rev(c$label))
  pc <- ggplot(c, aes(y = label)) +
    geom_segment(aes(x = low, xend = high, yend = label, colour = label), linewidth = 1.2) +
    geom_point(data = c[1, ], aes(x = value), size = 2.2, colour = NAVY) +
    scale_colour_manual(values = c("Bootstrap" = NAVY, "Leave-one-out" = ORANGE)) +
    scale_x_continuous(limits = c(.74, 1), breaks = c(.8, .9, 1)) +
    labs(x = "Spearman ρ", y = NULL) + xgrid() + theme(legend.position = "none")
  draw_figure("paper1_figure2_mixture_semantics", list(panel(pa, "Mixture coordinate", a),
    panel(pb, "Sample shape", b), panel(pc, "Uncertainty", c)), height = 70, widths = c(57, 47, 60))
}
paper1_figure3_artifact_controls <- function() {
  t <- historical("artifact_triage"); m <- historical("ambient_invariance")
  a <- data.frame(label = c("Stress\nSMD", "PTPRC\nratio"),
     raw = c(t$H1_dissociation$smd, t$H2_doublet$rate_ratio),
     bound = c(t$thresholds$smd_reject, t$thresholds$ptprc_ratio_reject))
  a$value <- a$raw / a$bound
  pa <- columns(a, "Observed / rejection bound", c(ORANGE, ORANGE), c(0, 1.15)) +
    geom_hline(yintercept = 1, linetype = "dashed", colour = RED, linewidth = .35)
  b <- data.frame(before = num(t$depth_control_per_sample, "before"), after = num(t$depth_control_per_sample, "after"))
  pb <- ggplot(b, aes(before, after)) + geom_abline(slope = 1, intercept = 0, colour = GRAY, linetype = "dashed", linewidth = .3) +
    geom_point(size = 1.7, colour = BLUE) + coord_fixed(xlim = c(0, .9), ylim = c(0, .9)) +
    scale_x_continuous(breaks = c(0, .4, .8)) + scale_y_continuous(breaks = c(0, .4, .8)) +
    labs(x = "Before matching", y = "After matching")
  c <- data.frame(label = c("All", "RNA-\nexcluded"),
    value = c(m$test_A_purity$bimodal_all$delta_bic, m$test_A_purity$bimodal_pure$delta_bic))
  pc <- columns(c, "BIC (1 component − 2)", c(TEAL, TEAL), c(0, 65))
  draw_figure("paper1_figure3_artifact_controls", list(panel(pa, "Technical controls", a),
    panel(pb, "Depth matching", b), panel(pc, "Ambient RNA", c)), height = 66)
}
paper1_figure4_outcome_counterexample <- function() {
  a <- sample_data(historical("bimodal_stratification")$cohorts$GSE165816_discovery$per_sample)
  p <- historical("cohort_metadata/gse165816_patient_unit_remap")
  s <- repaired("patient_mapping_equivalence")
  pow <- historical("negative_result_strength")$observed_design_power
  design <- repaired("design_power_simulation")
  pa <- ggplot(a, aes(arm, weight, colour = arm, shape = arm)) +
    geom_point(position = position_jitter(width = .09, height = 0, seed = 4), size = 1.9) +
    stat_summary(fun.min = mean, fun.max = mean, geom = "errorbar", width = .22,
                 linewidth = .65, show.legend = FALSE) +
    scale_colour_manual(values = ARMS) + scale_shape_manual(values = c(16, 17, 15)) +
    scale_x_discrete(labels = c("Healer", "Non-\nhealer", "Healthy")) +
    coord_cartesian(ylim = c(0, .95)) + labs(x = NULL, y = "High-state fraction") + theme(legend.position = "none")
  e <- list(s$effect, p$effect_cell_weighted)
  b <- data.frame(label = c("14 samples", "11 patients"),
    value = num(e, "healer_minus_nonhealer_mean_difference"),
    low = vapply(e, function(x) x$bootstrap_95_ci[[1]], 0),
    high = vapply(e, function(x) x$bootstrap_95_ci[[2]], 0))
  pb <- forest(b, "Healer − non-healer", ref = 0, limits = c(-.01, .09)) +
    scale_x_continuous(limits = c(-.01, .09), breaks = c(0, .04, .08), expand = expansion(mult = .02))
  c <- data.frame(label = c("Observed", "Target"), value = c(pow$power_at_observed, design$protocol$target_power))
  pc <- columns(c, "Power", c(ORANGE, NAVY), c(0, 1)) +
    scale_y_continuous(breaks = c(0, .4, .8), labels = scales::label_percent())
  draw_figure("paper1_figure4_outcome_counterexample", list(panel(pa, "Mixture by arm", a),
    panel(pb, "Unit correction", b), panel(pc, "Design power", c)), height = 68, widths = c(54, 63, 47))
}
paper1_figure5_sensitivity_negative_controls <- function() {
  s <- historical("method_constant_sensitivity"); n <- historical("pipeline_negative_control")
  a <- data.frame(cut = num(s$cut_sweep$rows, "cut"), rho = num(s$cut_sweep$rows, "A_rho_mean_vs_weight"),
                  p = num(s$cut_sweep$rows, "C_p"))
  line_cut <- function() geom_vline(xintercept = s$cut_sweep$gmm_cut, colour = GRAY, linetype = "dashed", linewidth = .3)
  pa <- ggplot(a, aes(cut, rho)) + geom_line(colour = BLUE, linewidth = .6) + line_cut() +
    coord_cartesian(ylim = c(.88, .97)) + labs(x = "State cut", y = "Spearman ρ")
  pb <- ggplot(a, aes(cut, p)) + geom_hline(yintercept = .05, linetype = "dashed", colour = RED, linewidth = .3) +
    geom_line(colour = ORANGE, linewidth = .55) + geom_point(colour = ORANGE, size = 1.1) + line_cut() +
    coord_cartesian(ylim = c(.035, .07)) + labs(x = "State cut", y = "Healing-arm p")
  k <- data.frame(K = num(s$k_sweep$rows, "K"), rho = num(s$k_sweep$rows, "A_rho_mean_vs_weight"))
  pc <- ggplot(k, aes(K, rho)) + geom_line(colour = BLUE, linewidth = .5) + geom_point(size = 2, colour = c(ORANGE, BLUE, BLUE)) +
    scale_x_continuous(breaks = c(10, 15, 20)) + coord_cartesian(ylim = c(.88, .97)) + labs(x = "Topics K", y = "Spearman ρ")
  d <- data.frame(label = c("Observed", "Null 95%"), value = c(n$N1_label_permutation$observed, NA),
    low = c(NA, n$N1_label_permutation$null_ci95[[1]]), high = c(NA, n$N1_label_permutation$null_ci95[[2]]))
  d$label <- factor(d$label, levels = rev(d$label))
  pd <- ggplot(d, aes(y = label)) + zero_v() +
    geom_segment(data = d[2, ], aes(x = low, xend = high, yend = label), colour = BLUE, linewidth = 1.5) +
    geom_point(data = d[1, ], aes(x = value), colour = RED, size = 2) +
    scale_x_continuous(limits = c(-.4, .4), breaks = c(-.3, 0, .3)) + labs(x = "Arm difference", y = NULL) + xgrid()
  e <- data.frame(label = c("Intact", "Shuffled"), value = c(n$N2_structureless_input$perplexity_real, n$N2_structureless_input$perplexity_null))
  pe <- columns(e, "Cell perplexity", c(TEAL, GRAY), c(0, 16)) + scale_y_continuous(breaks = c(0, 5, 10, 15))
  f <- data.frame(label = c("Observed p", "Null rate"), value = c(n$N3_permuted_positive_control$p_real, n$N3_permuted_positive_control$fraction_significant_under_permutation))
  pf <- columns(f, "Probability", c(RED, BLUE), c(0, .065)) +
    geom_hline(yintercept = .05, linetype = "dashed", colour = GRAY, linewidth = .3) +
    scale_x_discrete(labels = c("Observed\np", "Null\nrate"))
  draw_figure("paper1_figure5_sensitivity_negative_controls", list(panel(pa, "Semantic association", a),
    panel(pb, "Healing contrast", a), panel(pc, "Topic count", k), panel(pd, "Label permutation", d),
    panel(pe, "Structureless input", e), panel(pf, "Null calibration", f)), nrow = 2, height = 119)
}
paper1_figure6_representation_inference <- function() {
  r <- repaired("representation_inference"); b <- historical("representation_benchmark")
  a <- data.frame(label = method_names, value = num(r$auc[methods], "loso_auc"),
    low = vapply(r$auc[methods], function(x) x$bootstrap_95_ci[[1]], 0),
    high = vapply(r$auc[methods], function(x) x$bootstrap_95_ci[[2]], 0),
    null_mean = num(r$permutation_null[methods], "null_auc_mean"))
  pa <- forest(a) + geom_errorbar(aes(xmin = null_mean, xmax = null_mean),
    orientation = "y", width = .17, linewidth = .55, colour = ORANGE)
  corr <- diag(4)
  for (i in 1:3) for (j in (i + 1):4) corr[i, j] <- corr[j, i] <- b$cross_method_spearman_representative[[paste(methods[i], methods[j], sep = "__")]]
  c <- expand.grid(row = 1:4, col = 1:4); c$rho <- corr[cbind(c$row, c$col)]
  pc <- ggplot(c, aes(col, row, fill = rho)) + geom_tile(colour = "white", linewidth = .35) +
    geom_text(aes(label = sprintf("%.2f", rho)), size = 7.5 / .pt,
              family = "Arial", fontface = "bold", colour = "black") +
    scale_fill_gradient2(low = "#AFC5D6", mid = "#F8FAFB", high = "#E1A1A1", limits = c(-1, 1), name = "ρ") +
    scale_x_continuous(breaks = 1:4, labels = method_names, expand = c(0, 0)) +
    scale_y_reverse(breaks = 1:4, labels = method_names, expand = c(0, 0)) +
    coord_fixed() + labs(x = NULL, y = NULL) +
    theme(axis.line = element_blank(), axis.ticks = element_blank(), panel.grid = element_blank(),
          legend.position = "right", legend.key.height = unit(15, "mm"), legend.key.width = unit(2.4, "mm"),
          legend.title = element_text(size = 8, colour = "black", face = "bold")) + guides(fill = guide_colorbar(display = "rectangles", nbin = 60,
              barheight = unit(28, "mm"), barwidth = unit(2.4, "mm")))
  draw_figure("paper1_figure6_representation_inference", list(panel(pa, "Leave-one-sample AUC", a),
    panel(pc, "Score correlation", c)), height = 71, widths = c(81, 88))
}
paper1_figure7_patient_unit_anatomy <- function() {
  r <- repaired("patient_unit_representation_benchmark"); t <- repaired("paired_anatomical_control")
  a <- data.frame(label = method_names, value = num(r$auc[methods], "auc"),
    low = vapply(r$auc[methods], function(x) x$bootstrap_95_ci[[1]], 0),
    high = vapply(r$auc[methods], function(x) x$bootstrap_95_ci[[2]], 0))
  c <- t$topic0_contrasts$topic0_all_mean
  b <- data.frame(label = "Fibroblast\ntopic", value = c$observed_difference_foot_minus_forearm,
                  low = c$bootstrap_95_ci[[1]], high = c$bootstrap_95_ci[[2]])
  pb <- ggplot(b, aes(label, value)) + zero_h() + geom_errorbar(aes(ymin = low, ymax = high), width = .15, colour = GREEN, linewidth = .6) +
    geom_point(size = 2.2, colour = GREEN) + coord_cartesian(ylim = c(-.03, .125)) + labs(x = NULL, y = "Foot − forearm loading")
  draw_figure("paper1_figure7_patient_unit_anatomy", list(panel(forest(a), "Patient-unit AUC", a),
    panel(pb, "Paired anatomy", b)), height = 66, widths = c(88, 81))
}
paper1_figure8_external_construct_audit <- function() {
  i <- repaired("external_immune_axis"); g <- repaired("external_gse268834_projection"); h <- repaired("external_gse248247_projection")
  cohort <- c("GSE223964", "GSE245703", "GSE268834")
  a <- data.frame(cohort = rep(cohort, 2), type = rep(c("Immune fraction", "B/plasma share"), each = 3),
    rho = c(vector(i$cross_cohort$strict_immune_rho[cohort[1:2]]), g$sample_level_associations$immune_fraction_exclusive$rho,
        vapply(i$cohorts[cohort[1:2]], function(x) x$sample_level_associations$b_plasma_share_of_immune$rho, 0),
        g$sample_level_associations$b_plasma_share_of_immune$rho))
  a$cohort <- factor(a$cohort, levels = rev(cohort))
  pa <- ggplot(a, aes(rho, cohort, colour = type, shape = type)) + zero_v() +
    geom_point(size = 2, position = position_dodge(width = .35)) +
    scale_colour_manual(values = c("Immune fraction" = TEAL, "B/plasma share" = PURPLE)) +
    scale_shape_manual(values = c("Immune fraction" = 16, "B/plasma share" = 15)) +
    scale_x_continuous(limits = c(-1, 1), breaks = c(-1, 0, 1)) +
    labs(x = "Spearman ρ", y = NULL) + xgrid() + guides(colour = guide_legend(ncol = 1), shape = guide_legend(ncol = 1))
  b <- data.frame(cohort = factor(cohort, levels = rev(cohort)),
    rho = c(vapply(i$cohorts[cohort[1:2]], function(x) x$sample_level_associations$median_genes_per_cell$rho, 0), g$sample_level_associations$median_genes_per_cell$rho))
  pb <- ggplot(b, aes(rho, cohort)) + zero_v() + geom_point(colour = ORANGE, size = 2) +
    scale_x_continuous(limits = c(-1, 1), breaks = c(-1, 0, 1)) + labs(x = "Spearman ρ", y = NULL) + xgrid()
  c <- data.frame(label = c("GSE268834", "GSE248247"),
    value = c(g$sample_level_group_contrasts$topic0_fibro_mean$difference_diabetic_minus_non_diabetic,
              h$sample_level_group_contrasts$topic0_fibro_mean$difference_diabetic_minus_non_diabetic))
  pc <- ggplot(c, aes(factor(label, levels = rev(label)), value)) + zero_h() +
    geom_point(aes(colour = label), size = 2.1) + scale_colour_manual(values = c("GSE268834" = GREEN, "GSE248247" = GRAY)) +
    scale_x_discrete(labels = c("GSE248247" = "248247", "GSE268834" = "268834")) +
    coord_cartesian(ylim = c(-.04, .075)) + labs(x = "GSE series", y = "Diabetic − non-diabetic") + theme(legend.position = "none")
  draw_figure("paper1_figure8_external_construct_audit", list(panel(pa, "Immune context", a),
    panel(pb, "Detected genes", b), panel(pc, "Group contrast", c)), height = 73, widths = c(59, 59, 46))
}

paper2_figure1_workflow <- function() {
  body <- readLines(file.path(ROOT, "manuscripts/r_tikz/temporal_design.tikz"))
  write_workflow("paper2_figure1_workflow", 111, body,
    c("Global timepoint holdout", "Held-out donor protocol", "Common evaluation and sensitivity analyses"))
}

paper2_figure2_wound7_transfer <- function() {
  h <- repaired("human_temporal_flow"); t <- repaired("donor_transfer_flow"); g <- repaired("donor_geometry_inference")
  a <- data.frame(label = c("Prediction", "Stay-still"), value = c(h$all_donors$predicted, h$all_donors$standstill))
  pa <- columns(a, "Energy distance", c(BLUE, GRAY), c(0, 1.7))
  b <- data.frame(label = names(t$per_donor), value = 100 * num(t$per_donor, "improvement"))
  pb <- columns(b, "Improvement (%)", c(GREEN, BLUE, TEAL), c(0, 100))
  c <- data.frame(group = c(rep("Same-time\ndonor", length(g$pairwise_inputs$between_donor_same_time)),
       rep("Same-donor\ntime", length(g$pairwise_inputs$between_time_same_donor))),
       value = c(num(g$pairwise_inputs$between_donor_same_time, "d"), num(g$pairwise_inputs$between_time_same_donor, "d")))
  c$group <- factor(c$group, levels = unique(c$group))
  pc <- ggplot(c, aes(group, value, colour = group, fill = group)) +
    geom_boxplot(width = .5, outlier.shape = NA, alpha = .15, linewidth = .4) +
    geom_point(position = position_jitter(width = .09, height = 0, seed = 47), size = 1.3, alpha = .8) +
    scale_colour_manual(values = c(TEAL, ORANGE)) + scale_fill_manual(values = c(TEAL, ORANGE)) +
    labs(x = NULL, y = "Pairwise distance") + theme(legend.position = "none")
  draw_figure("paper2_figure2_wound7_transfer", list(panel(pa, "Held-out Wound7", a),
    panel(pb, "Donor transfer", b), panel(pc, "Donor–time geometry", c)), height = 67)
}
paper2_figure3_time_axes <- function() {
  r <- repaired("time_parameterisation")
  keys <- c("rank", "days", "sqrt_days", "log_days")
  labels <- c("Rank", "Linear days", "Square-root days", "Log days")
  d <- do.call(rbind, lapply(seq_along(keys), function(i) data.frame(axis = labels[i], fraction = num(r$scans[[keys[i]]], "frac"), ed = num(r$scans[[keys[i]]], "ed"))))
  target <- data.frame(axis = labels, fraction = num(r$axes_results[keys], "claimed_fraction"), ed = num(r$axes_results[keys], "ed_at_claimed"))
  p <- ggplot(d, aes(fraction, ed, colour = axis, linetype = axis)) +
    geom_hline(yintercept = r$standstill, linetype = "dashed", colour = GRAY, linewidth = .35) +
    geom_line(linewidth = .65) + geom_point(data = target, size = 2) +
    scale_colour_manual(values = setNames(c(BLUE, RED, GREEN, PURPLE), labels)) +
    scale_linetype_manual(values = setNames(c("solid", "longdash", "dotted", "dotdash"), labels)) +
    labs(x = "Fraction along predicted path", y = "Energy distance") +
    guides(colour = guide_legend(nrow = 1), linetype = guide_legend(nrow = 1))
  # Retain the complete observed y range; do not truncate the linear-days curve.
  exported <- rbind(transform(d, point_type = "scan"), transform(target, point_type = "held_out_target"),
    data.frame(axis = "Stay-still", fraction = NA, ed = r$standstill, point_type = "baseline"))
  draw_figure("paper2_figure3_time_axes", list(panel(p, "Time parameterization", exported)), height = 70)
}
paper2_figure4_methods_benchmark <- function() {
  r <- repaired("donor_conditioned_benchmark")
  keys <- c("M0_standstill", "M1_shared_cfm", "M2_mean_displacement", "M3_nearest_donor", "M4_conditioned_cfm", "M5_optimal_transport")
  a <- data.frame(label = c("Stay-\nstill", "Shared\nCFM", "Mean\nshift", "Nearest\ndonor", "Cond.\nCFM", "OT"), value = num(r$summary[keys], "mean_ed"))
  pa <- columns(a, "Mean energy distance", c(GRAY, NAVY, BLUE, TEAL, PURPLE, ORANGE))
  b <- do.call(rbind, lapply(names(r$in_sample), function(k) data.frame(fold = k,
    field = c("Shared", "Conditioned"), value = c(r$in_sample[[k]]$shared, r$in_sample[[k]]$conditioned))))
  b$field <- factor(b$field, levels = c("Shared", "Conditioned"))
  pb <- ggplot(b, aes(field, value, group = fold)) + geom_line(colour = PURPLE, alpha = .6, linewidth = .5) +
    geom_point(colour = PURPLE, size = 1.5) + labs(x = NULL, y = "Energy distance")
  draw_figure("paper2_figure4_methods_benchmark", list(panel(pa, "Held-out donor", a),
    panel(pb, "Training donors", b)), height = 68, widths = c(99, 70))
}
paper2_figure5_donor_curve_stability <- function() {
  s <- repaired("donor_curve_seed_stability"); c <- repaired("donor_count_curve"); r <- repaired("donor_curve_inference")
  a <- data.frame(k = rep(1:2, each = 3), seed = rep(names(s$per_seed), 2),
    value = c(num(s$per_seed, "k1_mean_ed"), num(s$per_seed, "k2_mean_ed")))
  fixed <- data.frame(k = 1:2, seed = "0", value = c(c$curve$k_1$shared_cfm_mean_ed, c$curve$k_2$shared_cfm_mean_ed))
  pa <- ggplot(a, aes(k, value)) + geom_line(data = fixed, colour = NAVY, linewidth = .6) +
    geom_point(aes(shape = seed), size = 2, colour = BLUE) +
    scale_shape_manual(values = c(16, 17, 15), name = "Seed") +
    scale_x_continuous(breaks = 1:2, labels = c("k = 1", "k = 2"), limits = c(.7, 2.3)) +
    labs(x = NULL, y = "Held-out energy distance") + theme(legend.title = element_text(size = 7, colour = "black", face = "bold"))
  b <- data.frame(seed = names(s$per_seed), reduction = vector(s$reduction_across_seeds$values),
    low = r$aggregate$donor_block_bootstrap_95_ci[[1]], high = r$aggregate$donor_block_bootstrap_95_ci[[2]],
    mean = r$aggregate$mean_reduction_across_donor_blocks)
  pb <- ggplot(b, aes(seed, reduction)) +
    annotate("rect", xmin = -Inf, xmax = Inf, ymin = b$low[1], ymax = b$high[1], fill = "#DFEAF1", colour = NA) +
    geom_hline(yintercept = 0, colour = GRAY, linewidth = .3) +
    geom_hline(yintercept = b$mean[1], colour = NAVY, linewidth = .55) +
    geom_point(size = 2.2, colour = ORANGE) + coord_cartesian(ylim = c(-.04, .39)) +
    labs(x = "Training seed", y = "ED reduction (k=1 − k=2)")
  draw_figure("paper2_figure5_donor_curve_stability", list(panel(pa, "Donor curve", a),
    panel(pb, "Seed stability", b)), height = 70)
}
paper2_figure6_mouse_arms <- function() {
  r <- repaired("mouse_all_arms_pod7_audit"); keys <- c("NDB", "PDB", "GDB")
  a <- data.frame(label = keys, value = 100 * num(r$arms[keys], "improvement_fraction"))
  pa <- columns(a, "Improvement (%)", c(GRAY, ORANGE, GREEN), c(-20, 65)) + zero_h()
  # Diagonal strokes drawn as vector segments within the off-path PDB bar.
  hatch <- function(center, half, top, spacing) {
    starts <- seq(-spacing, top, by = spacing)
    do.call(rbind, lapply(starts, function(y) {
      lo <- max(0, -y / spacing); hi <- min(1, (top - y) / spacing)
      if (lo >= hi) return(NULL)
      data.frame(x = center - half + 2 * half * lo, xend = center - half + 2 * half * hi,
                 y = y + spacing * lo, yend = y + spacing * hi)
    }))
  }
  pa <- pa + geom_segment(data = hatch(2, .29, a$value[2], 5),
    aes(x = x, xend = xend, y = y, yend = yend), inherit.aes = FALSE, colour = "white", linewidth = .25)
  b <- data.frame(arm = rep(keys, 2), type = rep(c("Stay-still", "Prediction"), each = 3),
     value = c(num(r$arms[keys], "energy_distance_standstill"), num(r$arms[keys], "energy_distance_predicted")))
  b$x <- rep(1:3, 2) + rep(c(-.17, .17), each = 3)
  b$color <- c(rep("#C5CCD2", 3), GRAY, ORANGE, GREEN)
  pb <- ggplot(b, aes(x, value, fill = color)) + geom_col(width = .29) + scale_fill_identity() +
    scale_x_continuous(breaks = 1:3, labels = keys) + labs(x = NULL, y = "Energy distance")
  pb <- pb + geom_segment(data = hatch(2.17, .145, b$value[5], .055),
    aes(x = x, xend = xend, y = y, yend = yend), inherit.aes = FALSE, colour = "white", linewidth = .25)
  draw_figure("paper2_figure6_mouse_arms", list(panel(pa, "POD7 audit", a),
    panel(pb, "Baseline vs prediction", b)), height = 66)
}

names_all <- c(paste0("paper1_figure", 1:8, c("_workflow", "_mixture_semantics", "_artifact_controls", "_outcome_counterexample", "_sensitivity_negative_controls", "_representation_inference", "_patient_unit_anatomy", "_external_construct_audit")),
  paste0("paper2_figure", 1:6, c("_workflow", "_wound7_transfer", "_time_axes", "_methods_benchmark", "_donor_curve_stability", "_mouse_arms")))
selected <- if (length(requested)) requested else names_all
if (!all(selected %in% names_all)) stop("Unknown figure name")
for (name in selected) get(name, mode = "function")()
manifest <- list(renderer = "R + ggplot2/grid + tikzDevice + XeLaTeX", font = "Arial",
  text_colour = "#000000", text_weight = "bold",
  base_font_pt = 8, tick_font_pt = 7.5, label_font_pt = 11, journal_width_mm = 180,
  figures = figures, sources = sources, R = R.version.string,
  packages = lapply(c("ggplot2", "tikzDevice", "jsonlite", "digest"), function(p) list(package = p, version = as.character(packageVersion(p)))),
  design_sources = setNames(lapply(c("construct_design.tikz", "temporal_design.tikz"),
    function(f) digest::digest(file = file.path(ROOT, "manuscripts/r_tikz", f), algo = "sha256")),
    paste0("manuscripts/r_tikz/", c("construct_design.tikz", "temporal_design.tikz"))),
  script_sha256 = digest::digest(file = normalizePath(script), algo = "sha256"))
write_json(manifest, file.path(BUILD, "manifest.json"), auto_unbox = TRUE, pretty = TRUE, digits = NA)
writeLines(capture.output(sessionInfo()), file.path(BUILD, "sessionInfo.txt"))
