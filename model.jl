using Arrow
using GLM
using MixedModels
using RCall
using DataFrames

#2
ay_late_wds = Arrow.Table("data/ay.late.wds.arrow")
model1 = lm(@formula(vheight_mean ~ allophone), ay_late_wds)
# or, preferred/idiomatic syntax in Julia:
fit(LinearModel, @formula(vheight_mean ~ allophone), ay_late_wds)

#3
ay_late_wds_df = DataFrame(ay_late_wds)
uq_allophone = unique(ay_late_wds_df.allophone)
uq_participant = unique(ay_late_wds_df.participant)
newdata = allcombinations(
  DataFrame,
  "allophone" => uq_allophone,
  "participant" => uq_participant
)

predict(model1, newdata)
newdata.pred1 = predict(model1, newdata);
newdata

#4
@rput ay_late_wds_df
@rput newdata
R"""
library(ggplot2)
ggplot(aes(x=allophone, y=vheight_mean), data=ay_late_wds_df) + 
  geom_jitter(width=.3, height=0, alpha = .1) + 
  geom_line(aes(y=pred1, group=participant), data=newdata) +
  xlab("Condition") + 
  ylab("Model prediction") + 
  facet_wrap(~participant)
"""

#5
model1a = fit(
  MixedModel,
  @formula(vheight_mean ~ allophone + (1 | participant)),
  ay_late_wds
)
R"""
library(lme4)
summary(lmer(vheight_mean ~ allophone + (1 | participant), 
        data = ay_late_wds_df, REML = FALSE))
"""
# Why REML=false in Julia? See:
# - From 2009: https://stat.ethz.ch/pipermail/r-sig-mixed-models/2009q1/002096.html
# - From 2023: https://github.com/RePsychLing/SMLP2023/discussions/24#discussioncomment-6990457

#6
model1b = fit(
  MixedModel,
  @formula(vheight_mean ~ allophone + (1 + allophone | participant)),
  ay_late_wds
)
model1b_nocor = fit(
  MixedModel,
  @formula(vheight_mean ~ allophone + zerocorr(1 + allophone | participant)),
  ay_late_wds
)

#7
MixedModels.likelihoodratiotest(model1a, model1b_nocor, model1b)

#8
ay = DataFrame(Arrow.Table("data/ay.arrow"))

mod2 = lm(
  @formula(vheight ~ gender_male * birthyear_z2 * allophone_ay0 +
                     logdur_z2 + frequency_z2),
  ay
);
coeftable(mod2)

# set decimal printing options for repl
using Printf
Base.show(io::IO, f::Float64) = @printf(io, "%.3f", f)

#9-12
fm_R_max = @formula(
  vheight ~ gender_male * birthyear_z2 * allophone_ay0 + 
            logdur_z2 + frequency_z2 +
            zerocorr(1 + logdur_z2 + frequency_z2 + allophone_ay0 | participant) + 
            zerocorr(1 + birthyear_z2 | word)
);
@time fit(MixedModel, fm_R_max, ay)
# For comparison to R:
model_R_max = @time fit(MixedModel, fm_R_max, ay; REML = true)
@printf("%.10f", model_R_max.objective)
model_R_max.optsum

# Fun with fit logs (get w/ `thin=1`)
model_R_max2 = fit(MixedModel, fm_R_max, ay; REML = true, thin = 1);
model_R_max2.optsum.fitlog
fit_params = first.(model_R_max2.optsum.fitlog)
fit_objective = last.(model_R_max2.optsum.fitlog)
@rput fit_params;
@rput fit_objective;
R"""
library(dplyr)
df_params <- as.data.frame(t(simplify2array(fit_params)))
df_params_long <- df_params %>% 
  stack() %>% 
  group_by(ind) %>%
  mutate(iter = row_number()) %>%
  ungroup()
plot_params <- ggplot(df_params_long, aes(iter, values, group = ind)) +
  geom_line(aes(color = ind), linewidth = 2)
plot_objective <- data.frame(iter = seq_along(fit_objective), y = fit_objective) %>% 
  ggplot(aes(iter, y)) +
  geom_line(linewidth = 1)
library(patchwork)
plot_params / plot_objective & plot_layout(heights = c(5, 1))
"""

fm_max = @formula(
  vheight ~ gender_male * birthyear_z2 * allophone_ay0 + 
            logdur_z2 + frequency_z2 +
            (logdur_z2 + frequency_z2 + allophone_ay0 | participant) + 
            (gender_male * birthyear_z2 + logdur_z2 | word)
);
@time model_max = fit(MixedModel, fm_max, ay; REML=true)
issingular(model_max)
MixedModels.likelihoodratiotest(model_R_max, model_max)
MixedModels.rePCA(model_max)

fm_max_minus1 = @formula(
  vheight ~ gender_male * birthyear_z2 * allophone_ay0 + 
            logdur_z2 + frequency_z2 +
            (logdur_z2 + frequency_z2 + allophone_ay0 | participant) + 
            (gender_male + birthyear_z2 + logdur_z2 | word)
);
@time model_max_minus1 = fit(MixedModel, fm_max_minus1, ay)
MixedModels.rePCA(model_max_minus1)
MixedModels.likelihoodratiotest(model_max_minus1, model_max)

fm_max_zerocorr = @formula(
  vheight ~ gender_male * birthyear_z2 * allophone_ay0 + 
            logdur_z2 + frequency_z2 +
            zerocorr(logdur_z2 + frequency_z2 + allophone_ay0 | participant) + 
            zerocorr(gender_male * birthyear_z2 + logdur_z2 | word)
);
model_max_zerocorr = fit(MixedModel, fm_max_zerocorr, ay)
MixedModels.likelihoodratiotest(model_R_max, model_max_zerocorr, model_max)

# If time
using CairoMakie
using MixedModelsMakie
coefplot(model_max)
shrinkageplot(model_max)
caterpillar(model_max, :participant)
