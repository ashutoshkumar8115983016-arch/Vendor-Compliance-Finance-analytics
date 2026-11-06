# DAX Measures Documentation

> **Power BI model:** Vendor Monthly & Compliance Dashboard  
> **Measure table:** `Daxs`  
> **Total measures:** 41  
> **Purpose:** Document vendor payments, service charges, headcount, vendor movement, compliance-document tracking, and compliance risk.

---

## Table of Contents

1. [Page 1 — Vendor Payments & Overview](#page-1--vendor-payments--overview)
2. [Page 2 — Service Charge Analysis](#page-2--service-charge-analysis)
3. [Page 3 — Compliance Document Tracking](#page-3--compliance-document-tracking)
4. [Page 4 — Vendor & Headcount Movement](#page-4--vendor--headcount-movement)
5. [Page 6 — Compliance Risk & Actions](#page-6--compliance-risk--actions)
6. [Measure Dependencies](#measure-dependencies)
7. [Review Notes](#review-notes)

---

## Page 1 — Vendor Payments & Overview

### 1. Total_paid

**Purpose:** Calculates the total amount paid to vendors.

```dax
Total_paid =
SUM ( 'public fact_vendor_monthly'[total_amount_paid] )
```

**Format:** Indian Rupee (₹)

### 2. Total_CTC

**Purpose:** Calculates the total monthly CTC amount.

```dax
Total_CTC =
SUM ( 'public fact_vendor_monthly'[monthly_ctc_amount] )
```

**Format:** Indian Rupee (₹)

### 3. Total_gst

**Purpose:** Calculates the total GST charged on service charges.

```dax
Total_gst =
SUM ( 'public fact_vendor_monthly'[gst_on_service_charge] )
```

**Format:** Indian Rupee (₹)

### 4. Total_SC

**Purpose:** Calculates the total service charge amount.

```dax
Total_SC =
SUM ( 'public fact_vendor_monthly'[service_charge_amount] )
```

**Format:** Indian Rupee (₹)

### 5. SC%

**Purpose:** Calculates service charges as a percentage of total CTC. The result is multiplied by 100.

```dax
SC% =
DIVIDE ( [Total_SC], [Total_CTC] ) * 100
```

### 6. Head_count

**Purpose:** Calculates the current headcount for active vendors.

```dax
Head_count =
CALCULATE (
    SUM ( 'public fact_vendor_monthly'[current_headcount] ),
    'public fact_vendor_monthly'[vendor_status] = "Active"
)
```

**Format:** Whole number

### 7. Active Vendors

**Purpose:** Counts distinct vendors that have at least one active record in the vendor monthly fact table.

```dax
Active Vendors =
SUMX (
    VALUES ( 'public dim_vendor_site'[vendor_id] ),
    IF (
        CALCULATE (
            COUNTROWS ( 'public fact_vendor_monthly' ),
            'public fact_vendor_monthly'[vendor_status] = "Active"
        ) > 0,
        1,
        0
    )
)
```

**Format:** Whole number

### 8. New Vendors Final

**Purpose:** Counts vendors whose first active month is the currently selected month, excluding the first date key in the date table.

```dax
New Vendors Final =
VAR CurDate =
    MAX ( 'public dim_date'[month_start] )
VAR CurKey =
    YEAR ( CurDate ) * 10000 + MONTH ( CurDate ) * 100 + 1
VAR FirstKey =
    CALCULATE (
        MIN ( 'public dim_date'[date_key] ),
        ALL ( 'public dim_date' )
    )
RETURN
    SUMX (
        VALUES ( 'public dim_vendor_site'[vendor_id] ),
        VAR FirstActive =
            CALCULATE (
                MIN ( 'public fact_vendor_monthly'[date_key] ),
                'public fact_vendor_monthly'[vendor_status] = "Active",
                REMOVEFILTERS ( 'public dim_date' )
            )
        RETURN
            IF ( FirstActive = CurKey && FirstActive > FirstKey, 1, 0 )
    )
```

**Format:** Whole number

### 9. Terminated Vendors v2

**Purpose:** Counts vendors whose last active month was the month immediately before the currently selected month, excluding the last date key in the date table.

```dax
Terminated Vendors v2 =
VAR CurDate =
    MAX ( 'public dim_date'[month_start] )
VAR PrevDate =
    EDATE ( CurDate, -1 )
VAR PrevKey =
    YEAR ( PrevDate ) * 10000 + MONTH ( PrevDate ) * 100 + 1
VAR LastKey =
    CALCULATE (
        MAX ( 'public dim_date'[date_key] ),
        ALL ( 'public dim_date' )
    )
RETURN
    SUMX (
        VALUES ( 'public dim_vendor_site'[vendor_id] ),
        VAR LastActive =
            CALCULATE (
                MAX ( 'public fact_vendor_monthly'[date_key] ),
                'public fact_vendor_monthly'[vendor_status] = "Active",
                REMOVEFILTERS ( 'public dim_date' )
            )
        RETURN
            IF ( LastActive = PrevKey && LastActive < LastKey, 1, 0 )
    )
```

**Format:** Whole number

### 10. Previous Month Paid

**Purpose:** Returns the total amount paid in the previous month.

```dax
Previous Month Paid =
CALCULATE (
    [Total_paid],
    DATEADD ( 'public dim_date'[month_start], -1, MONTH )
)
```

### 11. MoM %

**Purpose:** Calculates month-over-month percentage change in total payments.

```dax
MoM % =
DIVIDE (
    [Total_paid] - [Previous Month Paid],
    [Previous Month Paid],
    0
)
```

**Format:** Percentage (one decimal place)

### 12. MoM Indicator

**Purpose:** Displays an up or down arrow with the month-over-month percentage change.

```dax
MoM Indicator =
VAR ChangePct = [MoM %]
RETURN
    SWITCH (
        TRUE (),
        ISBLANK ( ChangePct ), BLANK (),
        ChangePct < 0, "▼ " & FORMAT ( ChangePct, "0.0%" ),
        "▲ " & FORMAT ( ChangePct, "0.0%" )
    )
```

### 13. MoM Color

**Purpose:** Returns a colour code based on the month-over-month change.

```dax
MoM Color =
VAR ChangePct = [MoM %]
RETURN
    IF (
        ISBLANK ( ChangePct ),
        "#808080",
        IF ( ChangePct < 0, "#D32F2F", "#008000" )
    )
```

### 14. tota_paid_callout

**Purpose:** Dynamically changes the callout label based on whether one month is selected.

```dax
tota_paid_callout =
VAR nae =
    SELECTEDVALUE ( 'public dim_date'[month_name] )
RETURN
    IF (
        HASONEVALUE ( 'public dim_date'[month_name] ),
        nae & " Paid",
        "Total Paid"
    )
```

### 15. MOM KPI

**Purpose:** Displays a text label followed by the previous month's paid amount.

```dax
MOM KPI =
"Vs previously paid  " & [Previous Month Paid]
```

### 16. cost_hedcount

**Purpose:** Calculates the average payment amount per active headcount.

```dax
cost_hedcount =
DIVIDE ( [Total_paid], [Head_count], 0 )
```

---

## Page 2 — Service Charge Analysis

### 17. Avg SC % (Benchmark)

**Purpose:** Calculates the benchmark effective service-charge percentage across all sites by removing filters from the site master table.

```dax
Avg SC % (Benchmark) =
CALCULATE (
    [Effective SC %],
    ALL ( 'public vw_site_master' )
)
```

### 18. component_value

**Purpose:** Returns the relevant amount based on the selected component: CTC, Service Charge, or GST.

```dax
component_value =
SWITCH (
    SELECTEDVALUE ( Components[Component] ),
    "CTC", [Total_CTC],
    "Service Charge", [Total_SC],
    "GST", [Total_gst]
)
```

### 19. SC % Rank

**Purpose:** Ranks vendors by effective service-charge percentage in descending order, using dense ranking.

```dax
SC % Rank =
RANKX (
    ALL ( 'public vw_site_master'[vendor_name] ),
    [Effective SC %],
    ,
    DESC,
    Dense
)
```

**Format:** Whole number

### 20. Effective SC %

**Purpose:** Calculates the service-charge percentage for active vendor records.

```dax
Effective SC % =
CALCULATE (
    DIVIDE ( [Total_SC], [Total_CTC] ),
    'public fact_vendor_monthly'[vendor_status] = "Active"
)
```

**Format:** Percentage (two decimal places)

---

## Page 3 — Compliance Document Tracking

### 21. Compliance %

**Purpose:** Calculates the percentage of required compliance documents received.

```dax
Compliance % =
DIVIDE ( [Received Docs], [Required Docs] )
```

**Format:** Percentage (one decimal place)

### 22. Compliance Target

**Purpose:** Defines the compliance target as 90%.

```dax
Compliance Target =
0.90
```

**Format:** Percentage (whole number)

### 23. Doc Compliance %

**Purpose:** Calculates document compliance after excluding documents marked as not applicable (N/A) from the compliance base.

```dax
Doc Compliance % =
DIVIDE (
    [Received Docs],
    [Total Docs]
        - CALCULATE (
            COUNTROWS ( 'public fact_compliance_doc' ),
            'public dim_status'[status_name] = "N/A"
        ),
    0
)
```

**Format:** Percentage (one decimal place)

### 24. Missing Docs

**Purpose:** Calculates the number of required documents that have not been received.

```dax
Missing Docs =
[Required Docs] - [Received Docs]
```

**Format:** Whole number

### 25. Missing Docs Reminder-2

**Purpose:** Returns the number of missing documents for records with mail status `Reminder-2`.

```dax
Missing Docs Reminder-2 =
CALCULATE (
    [Missing Docs],
    'public fact_vendor_monthly'[mail_status] = "Reminder-2"
)
```

**Format:** Whole number

### 26. Received Docs

**Purpose:** Counts compliance-document records whose status is marked as received.

```dax
Received Docs =
CALCULATE (
    COUNTROWS ( 'public fact_compliance_doc' ),
    'public dim_status'[is_received] = 1
)
```

**Format:** Whole number

### 27. Required Docs

**Purpose:** Counts compliance-document records included in the compliance calculation base.

```dax
Required Docs =
CALCULATE (
    COUNTROWS ( 'public fact_compliance_doc' ),
    'public dim_status'[counts_in_compliance_base] = 1
)
```

**Format:** Whole number

### 28. Total Docs

**Purpose:** Counts all rows in the compliance document fact table.

```dax
Total Docs =
COUNTROWS ( 'public fact_compliance_doc' )
```

**Format:** Whole number

---

## Page 4 — Vendor & Headcount Movement

### 29. Cost of New Vendors

**Purpose:** Calculates the total amount paid for active vendors whose previous headcount was zero.

```dax
Cost of New Vendors =
CALCULATE (
    [Total_paid],
    'public fact_vendor_monthly'[previous_headcount] = 0,
    'public fact_vendor_monthly'[vendor_status] = "Active"
)
```

### 30. Headcount Change

**Purpose:** Calculates the difference between current headcount and previous month's headcount.

```dax
Headcount Change =
VAR CurrentHC = [Head_count]
VAR PrevHC =
    CALCULATE (
        [Head_count],
        DATEADD ( 'public dim_date'[month_start], -1, MONTH )
    )
RETURN
    CurrentHC - PrevHC
```

**Format:** Whole number

### 31. Headcount Change vs Start

**Purpose:** Calculates the difference between the current headcount and the headcount in the first month available in the date table.

```dax
Headcount Change vs Start =
VAR FirstM =
    CALCULATE (
        MIN ( 'public dim_date'[month_start] ),
        ALL ( 'public dim_date' )
    )
RETURN
    COALESCE ( [Head_count], 0 )
        - COALESCE (
            CALCULATE (
                [Head_count],
                REMOVEFILTERS ( 'public dim_date' ),
                'public dim_date'[month_start] = FirstM
            ),
            0
        )
```

**Format:** Whole number

### 32. Headcount of Closed Vendors

**Purpose:** Intended to calculate headcount associated with closed vendors.

```dax
Headcount of Closed Vendors =
CALCULATE (
    [Head_count],
    'public fact_vendor_monthly'[vendor_status] = "Closed"
)
```

**Format:** Whole number

---

## Page 6 — Compliance Risk & Actions

### 33. Reminder_Count

**Purpose:** Counts vendor monthly records with either `Reminder-1` or `Reminder-2` mail status.

```dax
Reminder_Count =
CALCULATE (
    COUNTROWS ( 'public fact_vendor_monthly' ),
    'public fact_vendor_monthly'[mail_status]
        IN { "Reminder-1", "Reminder-2" }
)
```

**Format:** Whole number

### 34. Compliance_Risk

**Purpose:** Converts the compliance percentage into a risk percentage. Lower compliance results in higher risk.

```dax
Compliance_Risk =
( 1 - [Compliance %] ) * 100
```

### 35. Action_Recommendation

**Purpose:** Generates a recommended action based on the risk score.

```dax
Action_Recommendation =
VAR _risk = [Risk_Score]
VAR _comp = [Compliance %]
VAR _late = [Late_Challan_Count]
RETURN
    SWITCH (
        TRUE (),
        _risk >= 70, "URGENT: Immediate audit required - compliance below 60%",
        _risk >= 50, "HIGH: Schedule review meeting this week",
        _risk >= 30, "MEDIUM: Send reminder and monitor",
        "LOW: No action needed"
    )
```

### 36. Late_Challan_Count

**Purpose:** Counts compliance documents with a document date later than the 15th of the month, considering only document types where `has_doc_date` is set to 1.

```dax
Late_Challan_Count =
COUNTROWS (
    FILTER (
        'public fact_compliance_doc',
        'public fact_compliance_doc'[doc_date] <> BLANK ()
            && RELATED ( 'public dim_doc_type'[has_doc_date] ) = 1
            && 'public fact_compliance_doc'[doc_date]
                > EOMONTH ( 'public fact_compliance_doc'[doc_date], -1 ) + 15
    )
)
```

**Format:** Whole number

### 37. Late_Filing_Risk

**Purpose:** Calculates late-filing risk as the percentage of late challans compared with received documents, multiplied by 100.

```dax
Late_Filing_Risk =
VAR _late = [Late_Challan_Count]
VAR _received = [Received Docs]
RETURN
    DIVIDE ( _late, _received, 0 ) * 100
```

### 38. Reminder_Risk

**Purpose:** Calculates reminder risk by comparing the current reminder count with the highest reminder count across vendors, multiplied by 100.

```dax
Reminder_Risk =
VAR _rem = [Reminder_Count]
VAR _max =
    MAXX (
        ALL ( 'public dim_vendor'[vendor_name] ),
        CALCULATE ( [Reminder_Count] )
    )
RETURN
    DIVIDE ( _rem, _max, 0 ) * 100
```

### 39. Risk_Score

**Purpose:** Calculates the weighted compliance risk score using compliance risk (50%), late-filing risk (30%), and reminder risk (20%).

```dax
Risk_Score =
    ( [Compliance_Risk] * 0.5 )
        + ( [Late_Filing_Risk] * 0.3 )
        + ( [Reminder_Risk] * 0.2 )
```

### 40. Top_Action_Reason

**Purpose:** Builds a summary of the top-action vendor's compliance percentage, late filings, reminder count, and recommended action.

```dax
Top_Action_Reason =
VAR _vendor = [Top_Action_Vendor]
VAR _comp =
    CALCULATE (
        [Compliance %],
        'public vw_site_master'[vendor_name] = _vendor
    )
VAR _late =
    CALCULATE (
        [Late_Challan_Count],
        'public vw_site_master'[vendor_name] = _vendor
    )
VAR _rem =
    CALCULATE (
        [Reminder_Count],
        'public vw_site_master'[vendor_name] = _vendor
    )
RETURN
    "Compliance: " & FORMAT ( _comp, "0%" )
        & " | Late Filings: " & _late
        & " | Reminders: " & _rem
        & " | Action: Immediate audit"
```

### 41. Top_Action_Vendor

**Purpose:** Identifies the vendor with the highest risk score.

```dax
Top_Action_Vendor =
VAR _top =
    TOPN (
        1,
        SUMMARIZE (
            ALL ( 'public vw_site_master'[vendor_name] ),
            'public vw_site_master'[vendor_name],
            "Risk", [Risk_Score]
        ),
        [Risk],
        DESC
    )
RETURN
    MAXX ( _top, 'public vw_site_master'[vendor_name] )
```

---

## Measure Dependencies

The following high-level dependency map shows how key measures build on one another.

```text
Vendor Payments & Overview
├── Total_paid
│   ├── Previous Month Paid
│   │   ├── MoM %
│   │   │   ├── MoM Indicator
│   │   │   └── MoM Color
│   │   └── MOM KPI
│   └── Cost of New Vendors
├── Total_CTC
│   ├── SC%
│   └── Effective SC %
│       ├── Avg SC % (Benchmark)
│       └── SC % Rank
├── Total_SC
│   └── component_value
├── Total_gst
│   └── component_value
└── Head_count
    ├── cost_hedcount
    ├── Headcount Change
    ├── Headcount Change vs Start
    └── Headcount of Closed Vendors

Compliance Document Tracking
├── Received Docs
├── Required Docs
│   ├── Compliance %
│   │   └── Compliance_Risk
│   └── Missing Docs
│       └── Missing Docs Reminder-2
└── Total Docs
    └── Doc Compliance %

Compliance Risk & Actions
├── Reminder_Count
│   ├── Reminder_Risk
│   └── Top_Action_Reason
├── Late_Challan_Count
│   ├── Late_Filing_Risk
│   └── Top_Action_Reason
├── Compliance_Risk
├── Risk_Score
│   ├── Action_Recommendation
│   ├── Top_Action_Vendor
│   └── Top_Action_Reason
└── Compliance %
```

---

## Review Notes

The following points are worth validating in the Power BI model. They are observations about the supplied DAX, not changes made to the formulas.

1. **Measure count:** The supplied model text contains 41 measures. The measure count in the introduction should therefore be 41.
2. **`SC%` versus `Effective SC %`:** `SC%` multiplies the ratio by 100, while `Effective SC %` returns the raw ratio and is formatted as a percentage. Confirm that visuals use the intended scale and format.
3. **`Headcount of Closed Vendors`:** The base measure `[Head_count]` filters `vendor_status = "Active"`, while this measure applies `vendor_status = "Closed"`. These filters conflict, so the result may be blank or zero. Consider creating a separate closed-headcount base calculation if closed headcount is required.
4. **`Action_Recommendation`:** Variables `_comp` and `_late` are declared but not used in the returned expression. Also, the urgent message says compliance is below 60%, while the condition is based on `_risk >= 70`. Confirm that this wording matches the intended business rule.
5. **`Late_Challan_Count`:** The formula treats a document as late when its date is after the 15th of the same month. Validate that this is the intended deadline logic for every included document type.
6. **`New Vendors Final` and `Terminated Vendors v2`:** These measures compare `date_key` values with month-start keys generated as `YYYYMM01`. Confirm that the date-key data type and granularity match this logic.
7. **`MOM KPI`:** This measure concatenates a text label with a numeric measure. Consider applying `FORMAT()` to `[Previous Month Paid]` if a formatted currency display is required.
8. **`tota_paid_callout` and `cost_hedcount`:** The supplied measure names contain these spellings. They have been retained as-is to preserve compatibility with existing visuals.

---

## Notes

- Measure names and DAX expressions are documented as supplied.
- Display folders (`Page 1`, `Page 2`, etc.) are retained as documentation sections.
- Currency and percentage formats are described where provided.
- Model lineage tags, annotations, and the Power Query partition definition are omitted because they are not required for end-user measure documentation.
- This document is for documentation purposes. It does not modify or validate the underlying Power BI model.


