using Arrow
using GLM
using MixedModels
using RCall
using DataFrames

#2
ay_late_wds = Arrow.Table("data/ay.late.wds.arrow")
model1 = lm(@formula(vheight_mean ~ allophone), ay_late_wds)

#3
ay_late_wds_df = DataFrame(ay_late_wds)
uq_allophone = unique(ay_late_wds_df.allophone)
uq_participant = unique(ay_late_wds_df.participant)
newdata = allcombinations(
  DataFrame,
  "allophone" => uq_allophone,
  "participant" => uq_participant
)

using Effects
effects!(newdata, model1);
newdata

#4
@rput ay_late_wds_df
@rput newdata
R"""
library(ggplot2)
ggplot(aes(x=allophone, y=vheight_mean), data=ay_late_wds_df) + 
  geom_jitter(width=.3, height=0, alpha = .1) + 
  geom_line(aes(group=participant), data=newdata) +
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

#9-12
fm_R_max = @formula(
  vheight ~ gender_male * birthyear_z2 * allophone_ay0 + 
            logdur_z2 + frequency_z2 +
            zerocorr(1 + logdur_z2 + frequency_z2 + allophone_ay0 | participant) + 
            zerocorr(1 + birthyear_z2 | word)
);
@time fit(MixedModel, fm_R_max, ay)

model_R_max = fit(MixedModel, fm_R_max, ay; thin = 1);
model_R_max.optsum.fitlog
fit_params = first.(model_R_max.optsum.fitlog)
fit_objective = last.(model_R_max.optsum.fitlog)
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
@time model_max = fit(MixedModel, fm_max, ay)
issingular(model_max)
MixedModels.likelihoodratiotest(model_R_max, model_max)

fm_max_zerocorr = @formula(
  vheight ~ gender_male * birthyear_z2 * allophone_ay0 + 
            logdur_z2 + frequency_z2 +
            zerocorr(logdur_z2 + frequency_z2 + allophone_ay0 | participant) + 
            zerocorr(gender_male * birthyear_z2 + logdur_z2 | word)
);
model_max_zerocorr = fit(MixedModel, fm_max_zerocorr, ay)
MixedModels.likelihoodratiotest(model_R_max, model_max_zerocorr, model_max)
