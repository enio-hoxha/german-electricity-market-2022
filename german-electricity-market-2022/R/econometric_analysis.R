# ==============================================================================
# MASTER IN DATA ANALYTICS - MEBD ASSIGNMENT
# Laura Ricco, Enio Hoxha
# EMPIRICAL ANALYSIS OF ELECTRICITY PRICES, LOAD, AND RENEWABLE GENERATION
# CASE STUDY: GERMANY (2022)
# ==============================================================================

# ------------------------------------------------------------------------------
# PHASE 1: ENVIRONMENT SETUP & DATA LOADING
# ------------------------------------------------------------------------------

rm(list = ls())

# Load required libraries (Install if missing using: install.packages(...))
library(tidyverse)
library(corrplot)
library(lubridate)
library(zoo)
library(ggplot2)
library(dplyr)
library(tidyr)

# Define exact file paths (Using your local directories)
path_baseline <- "cleaned_dataset_Germany.csv"
path_extended <- "cleaned_extension_dataset_Germany.csv"

# Load the baseline dataset
df <- read_csv(path_baseline)
df$obs_date <- as.Date(df$obs_date)

# Load the extended dataset (with separated Wind and Solar technologies)
df_ext <- read_csv(path_extended)
df_ext$obs_date <- as.Date(df_ext$obs_date)

# Perform preliminary Data Wrangling on the extended dataset
df_ext <- df_ext %>%
  mutate(
    total_daily_ren_gen = wind_gen + solar_gen,
    ren_share_pct = round((total_daily_ren_gen / total_daily_load) * 100, 2),
    month_factor = factor(month(obs_date, label = TRUE, abbr = TRUE)) # For Fixed Effects
  )

# Quick look at data structures
glimpse(df)
glimpse(df_ext)
summary (df)
summary (df_ext)

# ------------------------------------------------------------------------------
# PHASE 2: TASK 4.1 - DESCRIPTIVE PATTERNS (EVOLUTION OVER TIME)
# ------------------------------------------------------------------------------

# Prepare long format data for volume visualization
df_long_volumes <- df %>%
  select(obs_date, total_daily_load, total_daily_ren_gen, residual_load) %>%
  pivot_longer(cols = -obs_date, names_to = "Variable", values_to = "MWh")

# Plot A: Total Load vs Renewable Generation (Overlapping Lines)
ggplot(df_long_volumes, aes(x = obs_date, y = MWh, color = Variable)) +
  geom_line(alpha = 0.8) +
  # to make the month labels in English
  scale_x_date(
    date_breaks = "1 month",
    labels = function(x) month.abb[as.integer(format(x, "%m"))]
  ) +
  theme_minimal() +
  labs(title = "Evolution of Electricity Load and Renewable Generation (DE, 2022)",
       x = "Date", y = "Volume (MWh)", color = "Variable") +
  scale_color_manual(values = c("total_daily_load" = "black", 
                                "residual_load" = "red",
                                "total_daily_ren_gen" = "green"))

# Plot B: Price Trend and 7-day Moving Average
ggplot(df, aes(x = obs_date)) +
  geom_line(aes(y = avg_daily_price), color = "lightsteelblue", alpha = 0.7) +
  geom_line(aes(y = price_7d_ma), color = "darkblue", size = 1) +
  scale_x_date(
    date_breaks = "1 month",
    labels = function(x) month.abb[as.integer(format(x, "%m"))]
  ) +
  theme_minimal() +
  labs(title = "Day-Ahead Electricity Price Trend (DE_LU, 2022)",
       subtitle = "Daily price (light blue) vs 7-day Moving Average (dark blue)",
       x = "Date", y = "Price (EUR/MWh)")

# Plot C: Advanced Slicing - Facet Wrap Panels (Clearing Overplotting)
ggplot(df_long_volumes, aes(x = obs_date, y = MWh, color = Variable)) +
  geom_line(alpha = 0.8) +
  facet_wrap(~ Variable, ncol = 1, scales = "free_y", 
             labeller = as_labeller(c("total_daily_load" = "Total Load (Demand)",
                                      "residual_load" = "Residual Load (Net Load)",
                                      "total_daily_ren_gen" = "Renewable Generation"))) +
  scale_x_date(
    date_breaks = "1 month",
    labels = function(x) month.abb[as.integer(format(x, "%m"))]
  ) +
  theme_minimal() +
  labs(title = "Evolution of Electrical Variables (Germany, 2022)",
       subtitle = "Daily data separated for greater clarity",
       x = "Date", y = "Volume (MWh)") +
  theme(legend.position = "none", strip.text = element_text(face = "bold", size = 11))

# Plot D: Seasonal Trendlines using LOESS Smoothing
ggplot(df_long_volumes, aes(x = obs_date, y = MWh, color = Variable)) +
  geom_point(alpha = 0.2, size = 0.8) + 
  geom_smooth(method = "loess", span = 0.1, se = FALSE, linewidth = 1.2) +
  scale_x_date(
    date_breaks = "1 month",
    labels = function(x) month.abb[as.integer(format(x, "%m"))]
  ) +
  theme_minimal() +
  labs(title = "Macro Trends: Load vs Renewables",
       subtitle = "Points: daily measurements | Lines: smoothed trend (LOESS)",
       x = "Date", y = "Volume (MWh)", color = "Variable") +
  scale_color_manual(values = c("total_daily_load" = "black", "residual_load" = "red", "total_daily_ren_gen" = "green"),
                     labels = c("Residual Load", "Total Load", "Renewable Generation"))

# Plot E: Monthly Volume Distribution (Boxplots)
df_long_volumes_m <- df_long_volumes %>% mutate(month_label = month(obs_date, label = TRUE, abbr = TRUE,  locale = "en_US"))
ggplot(df_long_volumes_m, aes(x = month_label, y = MWh, fill = Variable)) +
  geom_boxplot(alpha = 0.7, outlier.size = 0.5) +
  facet_wrap(~ Variable, ncol = 1, scales = "free_y",
             labeller = as_labeller(c("total_daily_load" = "Total Load",
                                      "residual_load" = "Residual Load",
                                      "total_daily_ren_gen" = "Renewable Generation"))) +
  theme_minimal() +
  labs(title = "Monthly Volume Distribution and Variance (Germany, 2022)",
       subtitle = "Boxplots highlighting median, variance, and seasonal outliers",
       x = "Month", y = "Volume (MWh)") +
  theme(legend.position = "none", strip.text = element_text(face = "bold", size = 11))

# ------------------------------------------------------------------------------
# PHASE 3: TASK 4.2 - BASELINE RELATIONSHIPS & LINEAR COEFICIENTS
# ------------------------------------------------------------------------------

# 1. Correlation Analysis
df_cor <- df %>% select(avg_daily_price, total_daily_load, total_daily_ren_gen, residual_load, ren_share_pct)
cor_matrix <- cor(df_cor, use = "complete.obs")
corrplot(cor_matrix, method = "color", type = "upper", addCoef.col = "black", 
         tl.col = "black", tl.srt = 45, title = "Baseline Correlation Matrix", mar=c(0,0,1,0))

# 2. Linear Scatter Plot (Visualizing the Merit Order Effect)
ggplot(df, aes(x = ren_share_pct, y = avg_daily_price)) +
  geom_point(alpha = 0.5, color = "darkorange") +
  geom_smooth(method = "lm", color = "black", se = TRUE) +
  theme_minimal() +
  labs(title = "Effect of Renewable Share on Prices (Merit Order Effect)",
       x = "Renewable Share of Total Load (%)", y = "Daily Average Price (EUR/MWh)")

# 3. Baseline OLS Multiple Regression Model
model_base <- lm(avg_daily_price ~ total_daily_load + total_daily_ren_gen, data = df)
print("=== BASELINE OLS REGRESSION RESULTS ===")
summary(model_base)

# ------------------------------------------------------------------------------
# PHASE 4: EXTENSION 1 - TECHNOLOGICAL DISAGGREGATION (WIND VS SOLAR)
# ------------------------------------------------------------------------------

# 1. Extended OLS Model with Technology Split
model_ext <- lm(avg_daily_price ~ total_daily_load + wind_gen + solar_gen, data = df_ext)
print("=== EXTENDED OLS REGRESSION RESULTS (TECHNOLOGY SPLIT) ===")
summary(model_ext)

# 2. Disaggregated Scatter Plot (Asymmetric Impact)
df_ext_plot <- df_ext %>%
  select(avg_daily_price, wind_gen, solar_gen) %>%
  pivot_longer(cols = c(wind_gen, solar_gen), names_to = "Technology", values_to = "Generation_MWh") %>%
  mutate(Technology = recode(Technology, "wind_gen" = "Wind Energy", "solar_gen" = "Solar Energy"))

ggplot(df_ext_plot, aes(x = Generation_MWh, y = avg_daily_price, color = Technology)) +
  geom_point(alpha = 0.4) +
  geom_smooth(method = "lm", color = "black", se = TRUE) +
  facet_wrap(~ Technology, scales = "free_x") +
  theme_minimal() +
  labs(title = "Asymmetric Merit Order Effect: Wind vs Solar (Germany, 2022)",
       subtitle = "Comparing the daily price-depressing impact across technologies",
       x = "Daily Generation (MWh)", y = "Daily Average Price (€/MWh)") +
  scale_color_manual(values = c("Wind Energy" = "dodgerblue", "Solar Energy" = "orange")) +
  theme(legend.position = "none")

########### WIND vs SOLAR
# 1. Data preparation for technology comparison
df_tech_compare <- df_ext %>%
  select(obs_date, wind_gen, solar_gen) %>%
  pivot_longer(cols = c(wind_gen, solar_gen),
               names_to = "Technology",
               values_to = "MWh") %>%
  mutate(Technology = recode(Technology,
                             "wind_gen" = "Wind Generation",
                             "solar_gen" = "Solar Generation"))

# 2. Create the transparent area chart
ggplot(df_tech_compare, aes(x = obs_date, y = MWh, color = Technology, fill = Technology)) +
  # Use position = "identity" and a high transparency level (alpha = 0.4)
  # so that both generation profiles remain visible when overlapping
  geom_area(alpha = 0.4, position = "identity", linewidth = 0.5) +
  scale_x_date(
    date_breaks = "1 month",
    labels = function(x) month.abb[as.integer(format(x, "%m"))]
  ) +
  theme_minimal() +
  scale_color_manual(values = c("Wind Generation" = "dodgerblue",
                                "Solar Generation" = "orange")) +
  scale_fill_manual(values = c("Wind Generation" = "dodgerblue",
                               "Solar Generation" = "orange")) +
  labs(
    title = "Generation Profiles: Wind vs Solar (Germany, 2022)",
    x = "Date",
    y = "Daily Generation (MWh)"
  ) +
  theme(
    legend.position = "bottom",
    legend.title = element_blank()
  )

# ------------------------------------------------------------------------------
# PHASE 5: EXTENSION 2 - PRICE CANNIBALIZATION & MARKET REGIMES
# ------------------------------------------------------------------------------

# 1. Tail Event Extraction: Identifying Ultra-Low and Negative Price Days
df_extreme <- df_ext %>%
  filter(avg_daily_price < 30) %>%
  select(obs_date, avg_daily_price, ren_share_pct, wind_gen) %>%
  arrange(avg_daily_price)

print("=== DAYS WITH wholesale PRICE COLLAPSE (<30 EUR) ===")
print(df_extreme)

# 2. Non-Linear Price Cannibalization Curve (LOESS)
ggplot(df_ext, aes(x = ren_share_pct, y = avg_daily_price)) +
  geom_point(aes(color = avg_daily_price < 30), alpha = 0.7, size = 2) +
  geom_smooth(method = "loess", color = "darkred", linewidth = 1.2, se = TRUE) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "black") + 
  theme_minimal() +
  scale_color_manual(values = c("FALSE" = "darkgray", "TRUE" = "blue")) +
  labs(title = "Price Cannibalization Paradox (Germany, 2022)",
       subtitle = "Structural break: prices collapse vertically beyond critical renewable thresholds",
       x = "Renewable Share of Total Load (%)", y = "Daily Average Price (€/MWh)", color = "Price < 30 €/MWh") +
  theme(legend.position = "bottom")

# 3. Categorical Market Regimes Table
df_regimes <- df_ext %>%
  mutate(Regime = case_when(
    ren_share_pct < 30 ~ "1. Low Penetration (<30%)",
    ren_share_pct >= 30 & ren_share_pct <= 60 ~ "2. Medium Penetration (30-60%)",
    ren_share_pct > 60 ~ "3. High Penetration (>60%)"
  )) %>%
  group_by(Regime) %>%
  summarise(Days = n(), Avg_Price_Euro = round(mean(avg_daily_price), 2), Avg_Wind_MWh = round(mean(wind_gen), 0)) %>%
  arrange(Regime)

print("=== MACROECONOMIC MARKET REGIMES SUMMARY ===")
print(df_regimes)


# ------------------------------------------------------------------------------
# PHASE 6: PROFESSOR'S FEEDBACK - FIXED EFFECTS & GEOPOLITICAL RESIDUAL ANALYSIS
# ------------------------------------------------------------------------------

# 1. Advanced Econometric Refinement: Incorporating Monthly Fixed Effects
model_fe <- lm(avg_daily_price ~ total_daily_load + wind_gen + solar_gen + month_factor, data = df_ext)
print("=== ECONOMETRIC REFINEMENT: OLS WITH MONTHLY FIXED EFFECTS ===")
summary(model_fe)

# 2. Extracting Standardized Residuals (Non-arbitrary statistical outliers)
df_ext$standardized_residuals <- rstandard(model_fe)

# Plotting Standardized Residuals Over Time vs Geopolitical Timeline
ggplot(df_ext, aes(x = obs_date, y = standardized_residuals)) +
  geom_point(aes(color = abs(standardized_residuals) > 1.96), alpha = 0.6, size = 2) + # Z-score threshold |Z| > 1.96
  geom_hline(yintercept = 0, linetype = "dashed", color = "black") +
  geom_hline(yintercept = c(-2, 2), linetype = "dotted", color = "blue", linewidth = 0.8) + # 95% Confidence lines
  scale_x_date(
    date_breaks = "1 month",
    labels = function(x) month.abb[as.integer(format(x, "%m"))]
  ) +
  theme_minimal() +
  scale_color_manual(values = c("FALSE" = "darkgray", "TRUE" = "red")) +
  labs(title = "Standardized Residual Analysis Over Time (Germany, 2022)",
       subtitle = "Red points represent structural outliers mapping onto 2022 crisis events (|Z-Score| > 1.96)",
       x = "Date", y = "Standardized Residuals (Z-Scores)") +
  theme(legend.position = "none")

# Print identified structural anomaly days
outliers_days <- df_ext %>% filter(abs(standardized_residuals) > 1.96) %>% select(obs_date, avg_daily_price, standardized_residuals)
print("=== STATISTICALLY IDENTIFIED CRISIS OUTLIERS (|Z| > 1.96) ===")
print(outliers_days)

# ------------------------------------------------------------------------------
# PHASE 7: PROFESSOR'S FEEDBACK - JOINT SUPPLY-DEMAND INTERACTION ANALYSIS
# ------------------------------------------------------------------------------

# Isolate extreme wind supply (80th percentile) and check joint load interaction
wind_80_threshold <- quantile(df_ext$wind_gen, 0.80)
overall_median_load <- median(df_ext$total_daily_load)

df_interaction <- df_ext %>%
  filter(wind_gen >= wind_80_threshold) %>%
  mutate(Load_Condition = if_else(total_daily_load > overall_median_load, "High Demand (Above Median)", "Low Demand (Below Median)"))

summary_interaction <- df_interaction %>%
  group_by(Load_Condition) %>%
  summarise(Days_Count = n(), Average_Price_EUR = round(mean(avg_daily_price), 2),
            Average_Wind_MWh = round(mean(wind_gen), 0), Average_Load_MWh = round(mean(total_daily_load), 0))

print("=== JOINT EFFECT OF HIGH WIND SUPPLY AND GRID LOAD INTERACTION ===")
print(summary_interaction)

# Comprehensive Scatter Plot: Wind vs Price colored by continuous Load Intensity
ggplot(df_ext, aes(x = wind_gen, y = avg_daily_price, color = total_daily_load)) +
  geom_point(alpha = 0.7, size = 2.5) +
  scale_color_viridis_c(option = "C", name = "Total Load (MWh)") +
  # Separate regression slopes for Low Demand (Blue) vs High Demand (Red)
  geom_smooth(data = filter(df_ext, total_daily_load < overall_median_load), aes(x = wind_gen, y = avg_daily_price), method = "lm", se = FALSE, color = "blue", linetype = "dashed", size = 1) +
  geom_smooth(data = filter(df_ext, total_daily_load >= overall_median_load), aes(x = wind_gen, y = avg_daily_price), method = "lm", se = FALSE, color = "red", linetype = "dashed", size = 1) +
  theme_minimal() +
  labs(title = "Joint Supply-Demand Interaction: Wind Generation vs Price Dynamics",
       subtitle = "Dashed lines represent the distinct price-wind slopes under Low Demand (Blue) vs High Demand (Red)",
       x = "Daily Wind Generation (MWh)", y = "Daily Average Price (€/MWh)") +
  theme(legend.position = "right")

# ==============================================================================
# END OF CODE 
# ==============================================================================
