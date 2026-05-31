# DAX Measures — Retail Merchandising Intelligence Dashboard

**Project:** Retail Merchandising Analytics  
**Report:** Power BI Merchandising Intelligence Report  
**Data Model:** Star Schema · MS SQL Server → Power BI Import Mode  
**Measure Tables:** `Measures\_Category` · `Measures\_Vendor` · `Measures\_Promo` · `Measures\_Channel` · `Measures\_MIS`  
**Base Tables:** `Sales` · `Calendar` · `Dim\_Product` · `Dim\_Vendor` · `Dim\_Promo` · `Dim\_Channel`

\---

## Table of Contents

1. [Data Model Overview](#1-data-model-overview)
2. [Measures\_Category — Category Overview](#2-measures_category--category-overview)
3. [Measures\_Vendor — Vendor Performance](#3-measures_vendor--vendor-performance)
4. [Measures\_Promo — Promo Intelligence](#4-measures_promo--promo-intelligence)
5. [Measures\_Channel — Channel \& Freight](#5-measures_channel--channel--freight)
6. [Measures\_MIS — Weekly MIS](#6-measures_mis--weekly-mis)
7. [Design Conventions](#7-design-conventions)

\---

## 1\. Data Model Overview

```
Fact Table
└── Sales
      ├── sales          (revenue £/₹)
      ├── profit         (gross profit)
      ├── quantity       (units sold)
      ├── fill\_rate      (vendor fill rate 0–1)
      ├── week           (week number FK → Calendar)
      ├── category       (FK → Dim\_Product)
      └── vendor         (FK → Dim\_Vendor)

Dimension Tables
├── Calendar             week\_number, Quarter, Quarter\_Label, Week\_Label
├── Dim\_Product          category, subcategory
├── Dim\_Vendor           vendor, region
├── Dim\_Promo            promo\_flag, promo\_type
└── Dim\_Channel          channel\_type (2P / 3P), freight\_cost, cost\_per\_unit
```

> \*\*Naming convention:\*\* All calculated measures live in dedicated measure tables (no measures mixed into fact/dim tables). This keeps the field list clean and makes ATS/GitHub keyword scanning straightforward.



\---

## 2\. Measures\_Category — Category Overview

These measures power the **📊 Category Overview** page: KPI cards, the Revenue × Category bar chart, the Margin × Category comparison chart, the Profit donut, the Units bar, and the Revenue vs Margin scatter.



\---

### 2.1 Total Revenue

```dax
Total Revenue =
SUM ( Sales\[sales] )
```

**Significance:** The foundational aggregation measure. Sums all revenue across every row in the `Sales` fact table. Participates in every page as a baseline KPI. All percentage and ratio measures divide against this. Respects all slicer/filter context automatically via the Power BI filter engine.



\---

### 2.2 Avg Gross Margin

```dax
Avg Gross Margin =
DIVIDE (
    SUM ( Sales\[profit] ),
    SUM ( Sales\[sales] ),
    0
)
```

**Significance:** Calculates gross margin percentage as `profit ÷ revenue`. The `DIVIDE` function safely handles division-by-zero (returns 0 instead of an error), which is critical when a slicer filters to a category with no sales. Used as the Y-axis on the scatter chart and as a card KPI. Industry threshold: margins above 30% indicate healthy category contribution.



\---

### 2.3 Portfolio Margin %

```dax
Portfolio Margin % =
CALCULATE (
    \[Avg Gross Margin],
    ALL ( Sales\[category] )
)
```

**Significance:** Computes the blended gross margin across **all** categories, ignoring any category filter context. Uses `ALL()` to break the filter on `Sales\[category]` while preserving all other slicers (date, vendor, etc.). This creates the benchmark reference line in the margin comparison chart — enabling at-a-glance identification of which categories are above vs. below portfolio average.



\---

### 2.4 Margin Status

```dax
Margin Status =
VAR \_margin = \[Avg Gross Margin]
VAR \_portfolio = \[Portfolio Margin %]
RETURN
    SWITCH (
        TRUE (),
        \_margin >= \_portfolio + 0.05, "▲ Above Avg",
        \_margin <= \_portfolio - 0.05, "▼ Below Avg",
        "→ At Par"
    )
```

**Significance:** Classifies each category's margin position relative to the portfolio benchmark using a ±5 percentage point tolerance band. `SWITCH(TRUE(), ...)` evaluates conditions in order and returns the first match — the idiomatic DAX pattern for multi-branch conditional logic. Output drives conditional formatting in the margin chart and the card visual on the Overview page.



\---

### 2.5 Margin Color

```dax
Margin Color =
VAR \_margin = \[Avg Gross Margin]
VAR \_portfolio = \[Portfolio Margin %]
RETURN
    IF ( \_margin >= \_portfolio, "#00C49F", "#FF6B6B" )
```

**Significance:** Returns a hex color string for dynamic conditional formatting. Green (`#00C49F`) when the category margin meets or beats portfolio; red (`#FF6B6B`) otherwise. Bound to the "Color saturation" / "Data color" property of bar and column charts — eliminating the need for static conditional formatting rules that break when data changes.

\---

### 2.6 Margin Risk Category

```dax
Margin Risk Category =
VAR \_threshold = 0.20
RETURN
    CALCULATE (
        DISTINCTCOUNT ( Sales\[category] ),
        FILTER (
            VALUES ( Sales\[category] ),
            \[Avg Gross Margin] < \_threshold
        )
    )
```

**Significance:** Counts distinct categories whose gross margin is below 20% — the at-risk threshold for retail category management. `FILTER` + `VALUES` is the correct DAX pattern for iterating dimension values and applying a measure-based condition; this cannot be done with a simple `COUNTIF`. Output surfaces as the "Margin Risk" KPI card, giving buyers an immediate count of categories requiring intervention.

\---

### 2.7 Category Color

```dax
Category Color =
VAR \_idx =
    RANKX (
        ALL ( Sales\[category] ),
        CALCULATE ( SUM ( Sales\[sales] ) ),
        ,
        DESC,
        DENSE
    )
RETURN
    SWITCH (
        \_idx,
        1, "#004990",
        2, "#00B4D8",
        3, "#0077B6",
        4, "#48CAE4",
        5, "#90E0EF",
        "#ADB5BD"
    )
```

**Significance:** Assigns brand-palette hex colors to categories by revenue rank using `RANKX` with `DENSE` tie-breaking. `ALL(Sales\[category])` removes filter context so ranking is always absolute, not relative to the current visual filter. The fallback `"#ADB5BD"` handles any category beyond rank 5. This ensures consistent color assignment across all pages and chart types.

\---

### 2.8 Top Category (Adjusted)

```dax
Top Category (Adjusted) =
CALCULATE (
    SELECTEDVALUE ( Sales\[category] ),
    TOPN (
        1,
        ALL ( Sales\[category] ),
        CALCULATE ( SUM ( Sales\[sales] ) ),
        DESC
    )
)
```

**Significance:** Returns the name of the single highest-revenue category as a text string, for display in the KPI card. `TOPN(1, ...)` selects the top row from all categories ranked by revenue; `SELECTEDVALUE` extracts the category name from that single-row table. The `ALL()` wrapper ensures this is always the global top category, unaffected by page-level slicers.

\---

### 2.9 Total Revenue KPI

```dax
Total Revenue KPI =
VAR \_rev = \[Total Revenue]
RETURN
    SWITCH (
        TRUE (),
        \_rev >= 1000000, FORMAT ( \_rev / 1000000, "0.0" ) \& "M",
        \_rev >= 1000,    FORMAT ( \_rev / 1000, "0.0" ) \& "K",
        FORMAT ( \_rev, "#,0" )
    )
```

**Significance:** Formats the revenue figure dynamically into human-readable K/M suffixes for the KPI card display. Cards in Power BI can struggle with auto-formatting on large numbers; this measure takes full control of the display string. `FORMAT()` applies locale-neutral number formatting, making the dashboard portable across regional Power BI settings.

\---

### 2.10 Units Badge

```dax
Units Badge =
VAR \_units = SUM ( Sales\[quantity] )
RETURN
    FORMAT ( \_units / 1000, "0.0" ) \& "K units"
```

**Significance:** Aggregates total units sold and formats as a compact "K units" badge string for the KPI card. Dividing by 1,000 and appending "K" keeps the card legible at any screen size. Useful for buyers who track units alongside revenue to monitor volume trends independently of pricing changes.

\---

### 2.11 Pts Above Avg Label

```dax
Pts Above Avg Label =
VAR \_margin = \[Avg Gross Margin]
VAR \_portfolio = \[Portfolio Margin %]
VAR \_delta = ROUND ( ( \_margin - \_portfolio ) \* 100, 1 )
RETURN
    IF (
        \_delta > 0,
        "+" \& FORMAT ( \_delta, "0.0" ) \& " pts above avg",
        BLANK ()
    )
```

**Significance:** Generates a dynamic annotation label shown only when the selected category outperforms the portfolio average. Multiplying by 100 converts the decimal margin to basis points (percentage points). Returns `BLANK()` when the category is at or below average — hiding the label entirely and keeping the card clean. Paired with `Pts Below Avg Label` for full coverage.

\---

### 2.12 Pts Below Avg Label

```dax
Pts Below Avg Label =
VAR \_margin = \[Avg Gross Margin]
VAR \_portfolio = \[Portfolio Margin %]
VAR \_delta = ROUND ( ( \_portfolio - \_margin ) \* 100, 1 )
RETURN
    IF (
        \_delta > 0,
        "-" \& FORMAT ( \_delta, "0.0" ) \& " pts below avg",
        BLANK ()
    )
```

**Significance:** Mirror of `Pts Above Avg Label`. Surfaces only when the category underperforms — giving buyers a precise deficit figure without cognitive overhead. The explicit negative prefix and `BLANK()` logic ensures only one of the two label measures is visible at any time, acting as a conditional toggle.

\---

## 3\. Measures\_Vendor — Vendor Performance

These measures power the **🏭 Vendor Performance** page: KPI cards, the Revenue vs Fill Rate scatter, the Revenue-by-vendor donut, and the vendor scorecard table.

\---

### 3.1 Total Revenue *(shared base)*

```dax
Total Revenue =
SUM ( Sales\[sales] )
```

*(Defined in `Measures\_Category`; referenced here by the vendor scatter and donut charts via cross-table measure reference.)*

\---

### 3.2 Revenue Contribution %

```dax
Revenue Contribution % =
DIVIDE (
    SUM ( Sales\[sales] ),
    CALCULATE ( SUM ( Sales\[sales] ), ALL ( Sales\[vendor] ) ),
    0
)
```

**Significance:** Calculates each vendor's share of total portfolio revenue. The denominator uses `ALL(Sales\[vendor])` to remove the vendor filter and compute the grand total, while the numerator stays in current filter context. This is the DAX equivalent of a SQL window function (`SUM() OVER ()`). Used in the scatter chart bubble size and the scorecard table to identify revenue concentration.

\---

### 3.3 Avg Fill Rate

```dax
Avg Fill Rate =
AVERAGE ( Sales\[fill\_rate] )
```

**Significance:** Computes mean vendor fill rate (proportion of orders fulfilled on time) across all transactions in context. Fill rate is a primary supply chain KPI — values below 85% typically indicate vendor reliability risk. Displayed on the scatter X-axis and the scorecard table.

\---

### 3.4 Avg Portfolio Fill Rate

```dax
Avg Portfolio Fill Rate =
CALCULATE (
    AVERAGE ( Sales\[fill\_rate] ),
    ALL ( Sales\[vendor] )
)
```

**Significance:** Computes the portfolio-wide average fill rate across all vendors, ignoring vendor filter context. Serves as the benchmark reference line in the scatter chart, enabling identification of vendors above/below the portfolio mean — the same design pattern used for `Portfolio Margin %` in category analysis.

\---

### 3.5 Vendor Rank

```dax
Vendor Rank =
RANKX (
    ALL ( Sales\[vendor] ),
    CALCULATE ( SUM ( Sales\[sales] ) ),
    ,
    DESC,
    DENSE
)
```

**Significance:** Ranks every vendor by revenue in descending order using dense ranking (no gaps when ties occur). `RANKX` with `ALL()` computes rank in absolute terms regardless of page filters, so rank 1 is always the top vendor globally. Displayed in the scorecard table — enables quick identification of strategic vs. tail vendors.

\---

### 3.6 Vendor Status

```dax
Vendor Status =
VAR \_fill = \[Avg Fill Rate]
VAR \_margin = \[Avg Gross Margin]
RETURN
    SWITCH (
        TRUE (),
        \_fill >= 0.90 \&\& \_margin >= 0.30, "✅ Strategic",
        \_fill >= 0.80 \&\& \_margin >= 0.20, "⚠️ Adequate",
        "🔴 At Risk"
    )
```

**Significance:** Classifies vendors into three tiers using a compound condition on fill rate and margin. The `\&\&` (AND) operator within `SWITCH(TRUE(), ...)` checks both dimensions simultaneously — vendors must clear both thresholds to qualify for a higher tier. This is a common retail vendor segmentation model (similar to Lowe's vendor scorecard). Displayed in the scorecard table with emoji status indicators.

\---

### 3.7 Dependency Risk

```dax
Dependency Risk =
VAR \_contrib = \[Revenue Contribution %]
RETURN
    SWITCH (
        TRUE (),
        \_contrib >= 0.25, "🔴 High",
        \_contrib >= 0.10, "🟡 Medium",
        "🟢 Low"
    )
```

**Significance:** Flags vendors who contribute a disproportionate share of portfolio revenue. A vendor representing ≥25% of revenue creates concentration risk — supply disruption would materially impact category performance. Thresholds mirror standard retail category management guidelines. Displayed in the scorecard alongside `Vendor Status` to give buyers a two-dimensional risk view.

\---

### 3.8 High Risk Vendors

```dax
High Risk Vendors =
CALCULATE (
    DISTINCTCOUNT ( Sales\[vendor] ),
    FILTER (
        VALUES ( Sales\[vendor] ),
        \[Vendor Status] = "🔴 At Risk"
    )
)
```

**Significance:** Counts vendors classified as "At Risk" (low fill rate AND low margin). Uses the `FILTER` + `VALUES` iteration pattern to apply a measure-level condition to a dimension column — the same architectural pattern as `Margin Risk Category`. Surfaces as a KPI card to give buyers an immediate escalation count.

\---

### 3.9 Dependency Risk Vendors

```dax
Dependency Risk Vendors =
CALCULATE (
    DISTINCTCOUNT ( Sales\[vendor] ),
    FILTER (
        VALUES ( Sales\[vendor] ),
        \[Dependency Risk] = "🔴 High"
    )
)
```

**Significance:** Counts vendors in the "High Dependency" tier (≥25% revenue contribution). A card showing both `High Risk Vendors` and `Dependency Risk Vendors` together gives category managers a fast read on the two distinct types of vendor exposure: operational risk (fill/margin) and strategic risk (concentration).

\---

### 3.10 Portfolio Fill Status

```dax
Portfolio Fill Status =
VAR \_fill = \[Avg Portfolio Fill Rate]
RETURN
    SWITCH (
        TRUE (),
        \_fill >= 0.90, "✅ Healthy (" \& FORMAT ( \_fill, "0.0%" ) \& ")",
        \_fill >= 0.80, "⚠️ Adequate (" \& FORMAT ( \_fill, "0.0%" ) \& ")",
        "🔴 Below Target (" \& FORMAT ( \_fill, "0.0%" ) \& ")"
    )
```

**Significance:** Converts the numeric portfolio fill rate into a descriptive card label with embedded percentage. Embedding the percentage inside the status string means the card displays actionable context ("Below Target — 74.3%") rather than just a number or just a label. Format string `"0.0%"` automatically multiplies by 100 and appends the % symbol.

\---

### 3.11 Vendor Bubble Color

```dax
Vendor Bubble Color =
VAR \_fill = \[Avg Fill Rate]
VAR \_margin = \[Avg Gross Margin]
RETURN
    SWITCH (
        TRUE (),
        \_fill >= 0.90 \&\& \_margin >= 0.30, "#00C49F",
        \_fill >= 0.80 \&\& \_margin >= 0.20, "#FFB347",
        "#FF6B6B"
    )
```

**Significance:** Returns hex color for scatter chart bubbles using the same compound-condition logic as `Vendor Status`. Color encodes vendor health at a glance — green for strategic, amber for adequate, red for at-risk — making the scatter chart a self-explanatory quadrant analysis tool without needing a legend.

\---

### 3.12 Card Text

```dax
Card Text =
VAR \_count = DISTINCTCOUNT ( Sales\[vendor] )
RETURN
    FORMAT ( \_count, "0" ) \& " Active Vendors"
```

**Significance:** Generates a dynamic label for the vendor count KPI card. `DISTINCTCOUNT` respects all slicer/filter context, so the count updates when a category or date filter is applied — showing active vendors within that context rather than a static total.

\---

## 4\. Measures\_Promo — Promo Intelligence

These measures power the **🎯 Promo Intelligence** page: KPI cards, the Promo Lift % bar chart, the Baseline vs Promo Sales comparison chart, and the promo verdict table.

\---

### 4.1 Baseline Sales

```dax
Baseline Sales =
CALCULATE (
    SUM ( Sales\[sales] ),
    Sales\[promo\_flag] = 0
)
```

**Significance:** Filters the `Sales` table to non-promotional periods (`promo\_flag = 0`) and sums revenue. This establishes the counterfactual baseline — what the category earns without a promotion running. The measure is the denominator and reference point for all promo lift calculations.

\---

### 4.2 Promo Sales

```dax
Promo Sales =
CALCULATE (
    SUM ( Sales\[sales] ),
    Sales\[promo\_flag] = 1
)
```

**Significance:** Filters to promotional periods only and sums revenue. Paired with `Baseline Sales`, this enables direct comparison of promoted vs. non-promoted performance in the same visual — without any pre-aggregation in the data model.

\---

### 4.3 Promo Lift %

```dax
Promo Lift % =
DIVIDE (
    \[Promo Sales] - \[Baseline Sales],
    \[Baseline Sales],
    0
)
```

**Significance:** Core promo effectiveness metric. Calculates the incremental revenue percentage generated by the promotion relative to baseline. Positive lift means the promotion drove incremental sales; negative lift means the promotion cannibalized regular demand or coincided with a demand drop. Used as the primary Y-axis in the Promo Lift bar chart.

\---

### 4.4 Baseline Margin %

```dax
Baseline Margin % =
CALCULATE (
    DIVIDE ( SUM ( Sales\[profit] ), SUM ( Sales\[sales] ), 0 ),
    Sales\[promo\_flag] = 0
)
```

**Significance:** Computes gross margin rate during non-promotional periods. This is the pre-promotion margin baseline, which is typically higher because promotions involve price reductions or incremental cost (e.g., point-of-sale materials, co-op funding). Used alongside `Promo Margin %` to quantify the margin trade-off.

\---

### 4.5 Promo Margin %

```dax
Promo Margin % =
CALCULATE (
    DIVIDE ( SUM ( Sales\[profit] ), SUM ( Sales\[sales] ), 0 ),
    Sales\[promo\_flag] = 1
)
```

**Significance:** Gross margin rate during promotional periods. Almost always lower than `Baseline Margin %` due to promotional discounting. The gap between the two margins is the central insight of the Promo Intelligence page — a category with high lift but sharply negative margin delta may not be worth promoting.

\---

### 4.6 Margin Delta %

```dax
Margin Delta % =
\[Promo Margin %] - \[Baseline Margin %]
```

**Significance:** The margin impact of running the promotion, expressed in percentage points. A negative delta is expected but manageable if promo lift is high enough to compensate via volume. A large negative delta with low lift is the worst-case scenario — the promotion destroys margin without driving meaningful incremental sales. Displayed in the promo verdict table.

\---

### 4.7 Promo Verdict

```dax
Promo Verdict =
VAR \_lift = \[Promo Lift %]
VAR \_delta = \[Margin Delta %]
RETURN
    SWITCH (
        TRUE (),
        \_lift >= 0.15 \&\& \_delta >= -0.05, "✅ Worth It",
        \_lift >= 0.05 \&\& \_delta >= -0.10, "⚠️ Marginal",
        "❌ Not Worth It"
    )
```

**Significance:** Synthesises lift and margin delta into a single actionable verdict for category buyers. The compound conditions reflect standard retail promotion evaluation criteria: a promotion that lifts revenue by ≥15% with a margin erosion of ≤5 pts is clearly worth repeating; below those thresholds, the trade-off deteriorates. This converts a two-metric analysis into a one-click decision aid.

\---

### 4.8 Worth-It Promos

```dax
Worth-It Promos =
CALCULATE (
    DISTINCTCOUNT ( Sales\[category] ),
    FILTER (
        VALUES ( Sales\[category] ),
        \[Promo Verdict] = "✅ Worth It"
    )
)
```

**Significance:** Counts categories where promotions pass the ROI threshold. Surfaces as a KPI card so buyers see at a glance how many categories have promotable demand patterns. The FILTER+VALUES pattern evaluates the verdict measure for each category in context — the correct approach since `Promo Verdict` itself depends on aggregated sales figures.

\---

### 4.9 Margin Risk Promos

```dax
Margin Risk Promos =
CALCULATE (
    DISTINCTCOUNT ( Sales\[category] ),
    FILTER (
        VALUES ( Sales\[category] ),
        \[Promo Verdict] = "❌ Not Worth It"
    )
)
```

**Significance:** Mirror of `Worth-It Promos` — counts categories where promotions fail the ROI test. Together, the two cards frame the promo portfolio split: buyers can immediately see "7 worth it, 3 not worth it" and prioritise accordingly.

\---

### 4.10 Best Promo Lift %

```dax
Best Promo Lift % =
MAXX (
    VALUES ( Sales\[category] ),
    \[Promo Lift %]
)
```

**Significance:** Finds the highest promo lift percentage across all categories in current filter context. `MAXX` is the DAX iterator that evaluates a measure for each row of a table and returns the maximum result — equivalent to `MAX(subquery)` in SQL. Displayed as a KPI card to anchor the range of what good looks like in the current selection.

\---

### 4.11 Worst Promo Lift %

```dax
Worst Promo Lift % =
MINX (
    VALUES ( Sales\[category] ),
    \[Promo Lift %]
)
```

**Significance:** Mirror of `Best Promo Lift %`, using `MINX` to find the lowest (or most negative) lift. When paired with Best on the same card row, buyers see the performance range at a glance: if worst is deeply negative, the promo portfolio has a problem category that needs investigation.

\---

### 4.12 Promo Lift Color

```dax
Promo Lift Color =
IF ( \[Promo Lift %] >= 0, "#00C49F", "#FF6B6B" )
```

**Significance:** Returns green for positive lift, red for negative lift. Used as a dynamic data color on the Promo Lift % bar chart. Negative lift bars render in red, making loss-generating promotions immediately visible without requiring a separate legend or manual formatting rule.

\---

## 5\. Measures\_Channel — Channel \& Freight

These measures power the **🚚 Channel \& Freight** page: KPI cards, the cost-per-unit comparison chart, the channel revenue comparison chart, and the channel decision table.

> \*\*Context:\*\* `2P` = first-party / own-channel sales. `3P` = third-party marketplace sales. The page compares profitability across channels to guide inventory allocation decisions.

\---

### 5.1 2P Revenue

```dax
2P Revenue =
CALCULATE (
    SUM ( Sales\[sales] ),
    Dim\_Channel\[channel\_type] = "2P"
)
```

**Significance:** Total revenue generated through the own (first-party) channel. The `CALCULATE` context modification filters the `Dim\_Channel` dimension, which propagates through the relationship to `Sales`. This isolates channel-specific revenue without duplicating data.

\---

### 5.2 3P Revenue

```dax
3P Revenue =
CALCULATE (
    SUM ( Sales\[sales] ),
    Dim\_Channel\[channel\_type] = "3P"
)
```

**Significance:** Revenue generated through third-party marketplace channels. Paired with `2P Revenue` in the channel comparison column chart — enabling side-by-side category analysis of revenue split across channels.

\---

### 5.3 2P Cost/Unit

```dax
2P Cost/Unit =
CALCULATE (
    DIVIDE (
        SUM ( Dim\_Channel\[freight\_cost] ),
        SUM ( Sales\[quantity] ),
        0
    ),
    Dim\_Channel\[channel\_type] = "2P"
)
```

**Significance:** Average freight/fulfilment cost per unit sold through own channel. Cost-per-unit is a more actionable logistics KPI than total freight cost because it normalises for volume — a category with high total freight may still be efficient on a per-unit basis. Used in the cost comparison chart and decision table.

\---

### 5.4 3P Cost/Unit

```dax
3P Cost/Unit =
CALCULATE (
    DIVIDE (
        SUM ( Dim\_Channel\[freight\_cost] ),
        SUM ( Sales\[quantity] ),
        0
    ),
    Dim\_Channel\[channel\_type] = "3P"
)
```

**Significance:** Average cost per unit through third-party channels. Third-party platforms typically charge marketplace fees on top of freight, so `3P Cost/Unit` often exceeds `2P Cost/Unit`. The gap between the two measures is what the `Freight Cost Diff Dynamic` measure quantifies.

\---

### 5.5 Freight Cost Diff Dynamic

```dax
Freight Cost Diff Dynamic =
VAR \_2p = \[2P Cost/Unit]
VAR \_3p = \[3P Cost/Unit]
VAR \_diff = \_3p - \_2p
RETURN
    IF (
        \_diff > 0,
        "3P costs +" \& FORMAT ( \_diff, "£0.00" ) \& " more/unit",
        "2P costs +" \& FORMAT ( ABS ( \_diff ), "£0.00" ) \& " more/unit"
    )
```

**Significance:** Generates a dynamic text annotation that tells the story of the cost difference in plain language. Instead of requiring the user to subtract two numbers, this measure surfaces the insight directly: "3P costs +£1.24 more/unit". The `IF` branch handles the case where 2P is actually more expensive, preventing a misleading label. Displayed as a KPI card.

\---

### 5.6 2P Net Margin %

```dax
2P Net Margin % =
CALCULATE (
    DIVIDE (
        SUM ( Sales\[profit] ) - SUM ( Dim\_Channel\[freight\_cost] ),
        SUM ( Sales\[sales] ),
        0
    ),
    Dim\_Channel\[channel\_type] = "2P"
)
```

**Significance:** Net margin for the 2P channel after deducting freight/fulfilment costs from gross profit. This is a more complete profitability picture than gross margin alone — a category may have high gross margin but be eroded by high own-channel distribution costs. Displayed in the channel decision table.

\---

### 5.7 3P Net Margin %

```dax
3P Net Margin % =
CALCULATE (
    DIVIDE (
        SUM ( Sales\[profit] ) - SUM ( Dim\_Channel\[freight\_cost] ),
        SUM ( Sales\[sales] ),
        0
    ),
    Dim\_Channel\[channel\_type] = "3P"
)
```

**Significance:** Net margin for the 3P channel. Third-party marketplace fees are embedded in `Dim\_Channel\[freight\_cost]` for the 3P rows, making the deduction logic identical to 2P. Comparing `2P Net Margin %` vs `3P Net Margin %` by category is the core analysis of this page.

\---

### 5.8 Online Margin Edge %

```dax
Online Margin Edge % =
\[2P Net Margin %] - \[3P Net Margin %]
```

**Significance:** The margin advantage (or disadvantage) of selling through own channel vs. third-party. A positive value means 2P is more profitable; a negative value means the marketplace is actually returning better net margins (typically because of volume-driven freight discounts or lower returns rates). Displayed as the headline KPI card on this page.

\---

### 5.9 Recommendation

```dax
Recommendation =
VAR \_edge = \[Online Margin Edge %]
VAR \_3p\_rev = \[3P Revenue]
VAR \_2p\_rev = \[2P Revenue]
RETURN
    SWITCH (
        TRUE (),
        \_edge >= 0.05 \&\& \_2p\_rev > \_3p\_rev,  "✅ Prioritise 2P",
        \_edge <= -0.05 \&\& \_3p\_rev > \_2p\_rev, "🔄 Shift to 3P",
        "⚖️ Balanced Mix"
    )
```

**Significance:** Synthesises margin edge and revenue volume into a channel allocation recommendation. Requiring both a margin advantage AND a higher revenue base reduces false positives — a category should not be pushed into 2P just because margins are marginally better if 3P is already generating most of the volume. The "Balanced Mix" default handles ambiguous cases without forcing a binary decision.

\---

## 6\. Measures\_MIS — Weekly MIS

These measures power the **📋 Weekly MIS** page: quarterly revenue KPI cards, the revenue trend line chart, the WoW change bar chart, the quarterly donut, and the peak/trough week cards.

\---

### 6.1 Weekly Revenue

```dax
Weekly Revenue =
CALCULATE (
    SUM ( Sales\[sales] ),
    ALLEXCEPT ( Calendar, Calendar\[Week\_Label] )
)
```

**Significance:** Aggregates revenue at the weekly grain, preserving filter context for `Week\_Label` but removing other calendar filters. `ALLEXCEPT` is precise context control — used here to ensure the line chart's X-axis (week) drives the measure correctly while still responding to category/vendor slicers on other dimensions.

\---

### 6.2 4W Rolling Avg

```dax
4W Rolling Avg =
VAR \_current\_week =
    MAX ( Calendar\[Week\_Number] )
RETURN
    CALCULATE (
        AVERAGE ( Sales\[sales] ),
        FILTER (
            ALL ( Calendar ),
            Calendar\[Week\_Number] >= \_current\_week - 3
                \&\& Calendar\[Week\_Number] <= \_current\_week
        )
    )
```

**Significance:** Calculates a 4-week trailing moving average of revenue — the standard smoothing technique for weekly retail data that masks one-off spikes from promotions or stock events. The `FILTER(ALL(Calendar), ...)` pattern creates a dynamic rolling window by anchoring to `MAX(Week\_Number)` in the current row context of the line chart. This is the canonical DAX rolling calculation pattern (equivalent to SQL `ROWS BETWEEN 3 PRECEDING AND CURRENT ROW`). Plotted as a secondary line on the trend chart to reveal the underlying demand signal beneath weekly noise.

\---

### 6.3 WoW Revenue Change %

```dax
WoW Revenue Change % =
VAR \_current = SUM ( Sales\[sales] )
VAR \_prior =
    CALCULATE (
        SUM ( Sales\[sales] ),
        FILTER (
            ALL ( Calendar ),
            Calendar\[Week\_Number] =
                MAX ( Calendar\[Week\_Number] ) - 1
        )
    )
RETURN
    DIVIDE ( \_current - \_prior, \_prior, BLANK () )
```

**Significance:** Week-over-week revenue growth rate. The prior week is retrieved by filtering `Calendar\[Week\_Number]` to exactly one less than the current week within `ALL(Calendar)` — a direct offset pattern that doesn't rely on `DATEADD` (which requires a contiguous date table, not a week-number integer). Returns `BLANK()` for the first week where no prior exists, preventing a misleading 100% change. Used as the Y-axis of the WoW change bar chart.

\---

### 6.4 WoW Color

```dax
WoW Color =
IF ( \[WoW Revenue Change %] >= 0, "#00C49F", "#FF6B6B" )
```

**Significance:** Green/red color assignment for the WoW bar chart, identical in logic to `Promo Lift Color`. Positive WoW weeks are green; negative weeks are red. Consistent color semantics across the report (green = good, red = bad) reduce the cognitive load for dashboard readers.

\---

### 6.5 Q1 Revenue

```dax
Q1 Revenue =
CALCULATE (
    SUM ( Sales\[sales] ),
    Calendar\[Quarter] = "Q1"
)
```

**Significance:** Total revenue for Quarter 1, isolated by filtering the `Calendar` dimension. One of four symmetric quarterly measures. Together the four cards provide the quarterly P\&L split without requiring a matrix visual — each card independently answers "how did Q1 perform?" regardless of any page slicer state.

\---

### 6.6 Q2 Revenue

```dax
Q2 Revenue =
CALCULATE (
    SUM ( Sales\[sales] ),
    Calendar\[Quarter] = "Q2"
)
```

**Significance:** Q2 equivalent of `Q1 Revenue`. Same architecture; isolates Q2 performance.

\---

### 6.7 Q3 Revenue

```dax
Q3 Revenue =
CALCULATE (
    SUM ( Sales\[sales] ),
    Calendar\[Quarter] = "Q3"
)
```

**Significance:** Q3 equivalent.

\---

### 6.8 Q4 Revenue

```dax
Q4 Revenue =
CALCULATE (
    SUM ( Sales\[sales] ),
    Calendar\[Quarter] = "Q4"
)
```

**Significance:** Q4 equivalent. Retail Q4 typically includes the holiday season peak; this card is expected to display the highest value and serves as a natural reference point for full-year performance benchmarking.

\---

### 6.9 Peak Week KPI

```dax
Peak Week KPI =
VAR \_max\_rev =
    MAXX (
        VALUES ( Calendar\[Week\_Label] ),
        \[Weekly Revenue]
    )
VAR \_peak\_week =
    CALCULATE (
        SELECTEDVALUE ( Calendar\[Week\_Label] ),
        FILTER (
            VALUES ( Calendar\[Week\_Label] ),
            \[Weekly Revenue] = \_max\_rev
        )
    )
RETURN
    \_peak\_week \& " · " \& FORMAT ( \_max\_rev / 1000, "£0.0K" )
```

**Significance:** Identifies and labels the single highest-revenue week as a composite string: `"Wk 47 · £124.3K"`. `MAXX` finds the peak revenue; the subsequent `FILTER + SELECTEDVALUE` retrieves the week label for that peak. Compositing both into one string means a single KPI card communicates both *when* and *how much* — eliminating the need for a separate visual.

\---

### 6.10 Weakest Week KPI

```dax
Weakest Week KPI =
VAR \_min\_rev =
    MINX (
        VALUES ( Calendar\[Week\_Label] ),
        \[Weekly Revenue]
    )
VAR \_weak\_week =
    CALCULATE (
        SELECTEDVALUE ( Calendar\[Week\_Label] ),
        FILTER (
            VALUES ( Calendar\[Week\_Label] ),
            \[Weekly Revenue] = \_min\_rev
        )
    )
RETURN
    \_weak\_week \& " · " \& FORMAT ( \_min\_rev / 1000, "£0.0K" )
```

**Significance:** Mirror of `Peak Week KPI`, using `MINX` to surface the lowest-revenue week. Identifying the weakest week is as important as the peak for category planning — it reveals off-season troughs, potential stockout periods, or failed promotional windows that need investigation.

\---

### 6.11 Event Lift %

```dax
Event Lift % =
VAR \_peak =
    MAXX (
        VALUES ( Calendar\[Week\_Label] ),
        \[Weekly Revenue]
    )
VAR \_avg = AVERAGEX (
    VALUES ( Calendar\[Week\_Label] ),
    \[Weekly Revenue]
)
RETURN
    DIVIDE ( \_peak - \_avg, \_avg, 0 )
```

**Significance:** The percentage by which the peak week exceeds the annual weekly average — a proxy for event-driven demand uplift (Black Friday, seasonal promotions, clearance events). High event lift with a sharp drop immediately after may indicate demand pull-forward rather than genuine category growth. Displayed as a KPI card alongside the trend line.

\---

### 6.12 Baseline Margin Normal

```dax
Baseline Margin Normal =
CALCULATE (
    \[Avg Gross Margin],
    Sales\[promo\_flag] = 0
)
```

**Significance:** The gross margin rate on non-promotional weeks — the "natural" category margin when no discounting is active. Used on the Weekly MIS page to anchor the margin narrative: when the trend line shows a dip, cross-referencing with promotional periods explains whether the dip was margin-driven or volume-driven.

\---

### 6.13 Quarter Label

```dax
Quarter Label =
SELECTEDVALUE ( Calendar\[Quarter\_Label] )
```

**Significance:** Returns the display label for the currently selected or iterated quarter, for use in the quarterly donut chart legend. `SELECTEDVALUE` returns the value when a single quarter is in context; returns `BLANK()` when multiple quarters are selected, preventing ambiguous labels on the donut segments.

\---

### 6.14 Week Label

```dax
Week Label =
SELECTEDVALUE ( Calendar\[Week\_Label] )
```

**Significance:** Parallel pattern to `Quarter Label`. Returns the current week's display label for use in chart axes and tooltip text. Using `SELECTEDVALUE` on a dimension column rather than displaying the raw key (`Week\_Number`) ensures human-readable axis labels (e.g., "Wk 14 · Apr") rather than integers.

\---

### 6.15 Week Number

```dax
Week Number =
SELECTEDVALUE ( Calendar\[Week\_Number] )
```

**Significance:** Returns the integer week number for use in the WoW bar chart's X-axis. The integer allows the axis to sort numerically (1→52) rather than alphabetically, which is critical for correct time-series ordering when `Week\_Label` is a string.

\---

## 7\. Design Conventions

### 7.1 Why `DIVIDE()` instead of `/`

All division operations in this model use `DIVIDE(numerator, denominator, alternate\_result)` rather than the `/` operator. The `/` operator throws a division-by-zero error that propagates to the visual; `DIVIDE()` returns the alternate result (typically `0` or `BLANK()`), keeping visuals clean when categories have no sales in the current filter context.

### 7.2 `VAR` / `RETURN` pattern

All multi-step measures use the `VAR ... RETURN` pattern rather than nesting functions. This improves:

* **Readability** — each intermediate value has a name
* **Performance** — DAX evaluates each `VAR` once; deep nesting can re-evaluate sub-expressions multiple times
* **Debugging** — changing `RETURN` to return a `VAR` value lets you inspect any intermediate step

### 7.3 `FILTER(VALUES(), measure\_condition)` pattern

Used throughout for "count of items meeting a measure-based condition" (e.g., `Margin Risk Category`, `High Risk Vendors`, `Worth-It Promos`). The correct pattern is:

```dax
CALCULATE (
    DISTINCTCOUNT ( Table\[Column] ),
    FILTER ( VALUES ( Table\[Column] ), \[Measure] = "condition" )
)
```

This cannot be simplified to `COUNTIF`-style syntax because the condition involves a *measure* (aggregated value) evaluated per dimension member, not a row-level column comparison.

### 7.4 `ALL()` vs `ALLEXCEPT()`

* **`ALL(Table\[Column])`** — removes filter on that specific column; all other filters remain intact
* **`ALLEXCEPT(Table, Table\[Column])`** — removes all filters on the table *except* the specified column

`Portfolio Margin %` and `Avg Portfolio Fill Rate` use `ALL(column)` to remove just the dimension being compared. `Weekly Revenue` uses `ALLEXCEPT(Calendar, Calendar\[Week\_Label])` to preserve week context while removing other calendar filters — a more surgical approach for time-series measures.

### 7.5 Color measure convention

All `\*Color` and `\*Bubble Color` measures return hex strings (`"#RRGGBB"`) and are bound to the **"Color saturation"** or **"Data colors – FX"** property of their respective visuals. This eliminates static conditional formatting rules, which break silently when underlying data changes.

\---

*Generated from `Retail\_Merchandising\_Dashboard.pbix` — ProJect23 · Md Yusuf*

