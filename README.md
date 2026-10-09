# german-electricity-market-2022
SQL data engineering pipeline and empirical econometric analysis in R evaluating Merit Order dynamics, technological asymmetry, and price cannibalization in the German electricity market (2022).

# German Electricity Market Crisis 2022: Merit Order Dynamics, Technological Asymmetry & Price Cannibalization

[![Language](https://img.shields.io/badge/Language-R%20%7C%20SQL-blue.svg)](https://www.r-project.org/)
[![Status](https://img.shields.io/badge/Status-Completed-success)]()
[![Domain](https://img.shields.io/badge/Domain-Energy%20Economics%20%7C%20ENTSO--E-darkblue)]()
[![Methodology](https://img.shields.io/badge/Methodology-Econometrics%20%7C%20Data%20Engineering-orange)]()

An empirical end-to-end data pipeline and econometric study investigating wholesale electricity price formation in the **Germany-Luxembourg (DE_LU)** bidding zone during the **2022 European Energy Crisis**.

The project implements a complete analytical pipeline:
1. **Data Engineering in SQL:** Ingestion, deduplication via window functions, geographic bidding zone harmonization, Common Table Expression (CTE) aggregations, and feature engineering.
2. **Econometric Modeling in R:** Multi-variable OLS, technological disaggregation (wind vs. solar), non-parametric LOESS estimation for price cannibalization, monthly fixed effects (R² = 66.9%), and standardized residual mapping to macroeconomic shocks.

**Full Research Paper:** [Download Report PDF](docs/German_Electricity_Market_2022_Report.pdf)

---

## Executive Summary & Key Findings

- **The Merit-Order Effect:** Wholesale electricity prices were systematically depressed by renewable generation. Distinguishing technologies reveals that **wind generation was the exclusive driver** of this suppression (reducing prices by ~€0.74/MWh per 10 GWh added, p < 2e-16), while solar showed no statistically significant daily impact due to midday demand synchronization.
- **Price Cannibalization Paradox:** At renewable penetration rates below 30–35%, prices remained determined by marginal fossil units (~€296/MWh). Above 60%, prices collapsed by **66%** to ~€99.4/MWh, culminating in a negative daily price (-€0.764/MWh on Dec 30, 2022) during low holiday demand and high storm-driven wind output.
- **Geopolitical & Macro Drivers:** Incorporating monthly fixed effects increased model explanatory power from **31.3% to 66.9%** (R²), absorbing major fuel price inflation. Standardized residuals (|Z| > 1.96) accurately captured exogenous crisis shocks: the initial Ukraine war outbreak (March), the Nord Stream 1 shutdown, and low Rhine river coal barge disruptions (August).

---

## Data Engineering Pipeline (SQL)

Raw hourly and 15-minute time series from **ENTSO-E** were cleaned and structured using PostgreSQL:

- **Frequency & Anomaly Audits:** Identified irregular timestamp gaps and captured ~10,000 negative price intervals in high-frequency records.
- **Deduplication via Window Functions:** Resolved over 186,000 duplicated load records and 37,000 price records by partitioning through unique observational units:

```sql
CREATE TABLE prices AS
SELECT * FROM (
    SELECT *, ROW_NUMBER() OVER (
        PARTITION BY datetime, bzn ORDER BY datetime
    ) AS rn
    FROM prices_raw
) t WHERE rn = 1;
Bidding Zone Harmonization: Standardized disjoint identifier conventions (DE, DE-LU, DE LU) to ensure valid relational joins across country and bidding-zone boundaries.

Daily Aggregations & Feature Engineering: Structured multi-stage CTEs computing daily load, total renewable generation, residual load (Load - RenGen), renewable share percentage, and 7-day price moving averages via window functions

Econometric Framework & Progression
Baseline OLS                  Extended: Disaggregation          Full Fixed-Effects Model
R² = 25.5%             ───►   R² = 31.3%                 ───►   R² = 66.9% (RSE = 75.5)

Price = f(Load, RenGen)        Price = f(Load, Wind, Solar)       Price = f(Load, Wind, Solar, MonthFE)
1. Technological Disaggregation (Wind vs. Solar)$$\text{Price}_t = \beta_0 + \beta_1 \text{Load}_t + \beta_2 \text{Wind}_t + \beta_3 \text{Solar}_t + \varepsilon_t$$Wind Generation ($\beta_2$): -7.44e-05 (t = -11.16, p < 2e-16). Wind operates unconstrained by human activity, injecting low-marginal-cost power during off-peak hours and displacing thermal generation.Solar Generation ($\beta_3$): +1.16e-05 (t = 0.67, p = 0.5015). Statistically insignificant at daily aggregates; solar output closely tracks midday consumption peaks and is absorbed without displacing baseload thermal capacity.

2. Price Cannibalization & Market Regimes
Market Regime,Renewable Penetration,Observations,Mean Price (€/MWh),Mean Wind (MWh)
Low Penetration,< 30%,119 days,€296.00,"626,537"
Medium Penetration,30% - 60%,211 days,€224.00,"1,511,020"
High Penetration,> 60%,35 days,€99.40,"3,126,989"
A transition from low to high renewable share triggered a 66.4% collapse in wholesale market clearing prices.

Key Visualizations
1. Asymmetric Merit Order Effect: Wind vs. Solar
Distinct price-depressing elasticities across generation technologies:

2. Price Cannibalization Paradox (LOESS Smoothing)
Non-linear structural collapse of market prices beyond critical renewable thresholds:

3. Crisis Outliers & Standardized Residuals
Residual z-score spikes mapping onto the 2022 geopolitical timeline (Ukraine war onset, Nord Stream throttling, Rhine river logistics crunch):

Repository Structure
├── data/
│   ├── processed_generation_data.csv       # Cleaned generation series
│   └── electricity_prices_2022.csv         # Wholesale day-ahead prices
├── sql/
│   └── data_pipeline_and_cleaning.sql      # Ingestion, deduplication, CTE pipeline
├── r/
│   └── econometric_analysis.R              # EDA, regressions, LOESS, residual checks
├── docs/
│   └── German_Electricity_Market_2022_Report.pdf
├── images/
│   ├── 01_wind_vs_solar_asymmetry.png
│   ├── 02_price_cannibalization_loess.png
│   └── 03_standardized_residuals_crisis.png
└── README.md

Authors
Enio Hoxha – M.Sc. in Data Analytics for Economics and Management, Free University of Bozen-Bolzano
Laura Ricco – M.Sc. in Data Analytics for Economics and Management, Free University of Bozen-Bolzano
