library(tidyverse)
library(arm)
library(arrow)

ay <- read_csv("PNC_ay2.csv")

ay <- ay %>% 
  mutate(logdur.z2 = rescale(log(dur)),
         birthyear.z2 = rescale(birthyear),
         allophone.ay0 = rescale(allophone),
         gender.male = rescale(gender),
         frequency.z2 = rescale(Lg10CD),
         vheight = -1*F1.n)

ay$allophone <- as_factor(ay$allophone)
contrasts(ay$allophone)
# contrasts(ay$allophone) <- cbind("ay0" = c(-.5,.5))
ay$allophone <- as.integer(ay$allophone == "ay0") - .5

#1 
ay.late <- subset(ay, birthyear > 1980)

ay.late.wds <- ay.late %>%
  group_by(participant, allophone, word) %>%
  summarize(vheight.mean = mean(vheight)) %>% 
  ungroup()

dir.create("data")
write_feather(janitor::clean_names(ay), "data/ay.arrow")
write_feather(janitor::clean_names(ay.late.wds), "data/ay.late.wds.arrow")

#2 
mod1 <- lm(vheight.mean ~ allophone, data = ay.late.wds)

summary(mod1)

#3
newdata <- data.frame(expand.grid(allophone=unique(ay.late.wds$allophone),
                                  participant=unique(ay.late.wds$participant)))

newdata$mod1.pred <- predict(mod1, newdata=newdata)
newdata

#4
ggplot(aes(x=allophone, y=vheight.mean), data=ay.late.wds) + 
  geom_jitter(width=.3, height=0, alpha = .1) + 
  geom_line(aes(x=allophone,y=mod1.pred, group=participant), data=newdata) +
  xlab("Condition") + 
  ylab("Model prediction") + 
  facet_wrap(~participant)

#5
mod1a <- lmer(vheight.mean ~ 
                allophone +
                (1|participant), 
              data=ay.late.wds)
summary(mod1a)

newdata$mod1a.pred <- predict(mod1a, newdata=newdata)
ggplot(aes(x=allophone, y=vheight.mean), data=ay.late.wds) + 
  geom_jitter(width=.3, height=0, alpha = .1) + 
  geom_line(aes(x=allophone,y=mod1a.pred, group=participant), data=newdata) +
  xlab("Condition") + 
  ylab("Model prediction") + 
  facet_wrap(~participant)

#6
mod1b <- lmer(vheight.mean ~ allophone +
                (allophone|participant),
              data=ay.late.wds)
summary(mod1b)

#7
anova(mod1b, mod1a, refit=F) 

mod1b_nocorr <- lmer(vheight.mean ~ allophone +
                       (allophone||participant),
                     data=ay.late.wds)
summary(mod1b_nocorr)
anova(mod1b_nocorr, mod1a, refit=F)
anova(mod1b, mod1b_nocorr, mod1a, refit=F) 

#8
mod2 <- lm(vheight ~ gender.male * birthyear.z2 * allophone.ay0 +
             logdur.z2  +
             frequency.z2,
           data=ay)
summary(mod2)

#9-12
# For me, this doesn't converge - is this a false positive? We don't know!
# See also:
# - https://rpubs.com/palday/lme4-singular-convergence
# - https://rpubs.com/bbolker/lme4trouble1
system.time({
  mod2b <- lmer(vheight ~ gender.male * birthyear.z2 * allophone.ay0 + 
                  logdur.z2 +
                  frequency.z2 +
                  (allophone.ay0 + logdur.z2 + frequency.z2 || participant) + 
                  (birthyear.z2 || word), 
                data=ay)
})
summary(mod2b)
sprintf("%.10f", REMLcrit(mod2b))

# calc.derivs=FALSE
system.time({
  mod2b2 <- lmer(vheight ~ gender.male * birthyear.z2 * allophone.ay0 + 
                   logdur.z2 +
                   frequency.z2 +
                   (allophone.ay0 + logdur.z2 + frequency.z2 || participant) + 
                   (birthyear.z2 || word), 
                 data=ay, control = lmerControl(b))
})

fm_R_max <- vheight ~ gender.male * birthyear.z2 * allophone.ay0 + 
  logdur.z2 +
  frequency.z2 +
  (allophone.ay0 + logdur.z2 + frequency.z2 || participant) + 
  (birthyear.z2 || word)

lmer(fm_R_max, ay, REML = FALSE, control = lmerControl(calc.derivs = FALSE))
