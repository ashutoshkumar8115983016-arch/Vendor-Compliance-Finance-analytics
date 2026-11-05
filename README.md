Vendor Compliance & Finance Analytics
PostgreSQL → Power BI | 25 vendors · 57 sites · 23 locations · 12 months
An end-to-end analytics project that tracks payments, headcount and statutory-compliance documents for outsourced manpower, security and NAPS (apprenticeship) vendors across India, in one dashboard.
> **All data is synthetic.** Vendor names, amounts and headcounts are fictional ("Ashutosh Logistics" is a made-up brand). The structure mirrors a real monthly vendor-tracking process.
![Executive Overview](screenshots/02_executive.png)
---
Business problem
Vendor compliance is often tracked in monthly Excel sheets: one row per vendor, one column per document (PF challan, ECR, ESIC, PT, LWF, salary UTR, muster roll, wage register). That makes it hard to answer basic questions:
Which vendors keep missing documents, and which documents?
How much are we paying, and how much of it is service charge and GST?
Is headcount growing, and where is it concentrated?
Which vendors need management attention first?
This project turns that sheet into a star-schema database and an interactive Power BI report.
Dashboard pages
#	Page	What it answers
1	Landing	Navigation and headline numbers
2	Executive Overview	Total paid vs previous month, cost vs compliance trend, spend by vendor type, vendor lifecycle
3	Payments Overview	CTC → service charge → GST waterfall, effective service charge by vendor and type, decomposition tree
4	Compliance Overview	Compliance % by document, vendor × month heatmap, target gauge, vendors with most missing documents
5	Workforce Trend	Headcount trend, location map, region split, current vs previous headcount
6	Vendor Scorecard	Drillthrough page: vendor-wise headcount, payment, compliance and service charge by month
7	Action Overview	Risk score per vendor and a recommended action

	
![Payments](screenshots/03_payments.png)	![Compliance](screenshots/04_compliance.png)
![Workforce](screenshots/05_workforce.png)	![Action](screenshots/07_action.png)
Key insights
(from the synthetic dataset, Sep'25 – Aug'26)
Overall compliance is 85.3%, below the 90% target. Monthly compliance ranges from 82.5% (Mar'26) to 87.6% (Nov'25).
Orbit Manpower Services and Kaveri Enterprises are the highest-risk active vendors (risk score about 43), with roughly 54–55% compliance and 24–25 reminders each.
Returns and records lag challans. PF Challan is the best document at 89.5%, while ESIC ECR (78.2%), PT Challan (79.5%) and PF ECR (79.7%) are the weakest.
Short-lived vendors were the least compliant. The three terminated vendors (Quickhire, Spark Temp, Lotus) all had compliance below 65%.
Total paid is ₹146.6 cr, and 92.6% of it goes to manpower vendors. Service charge adds ₹9.64 cr, an effective 7.13% of CTC. Security vendors charge the most (7.52%) and NAPS the least (5.00%).
Headcount grew from 5,314 to 5,736 (+7.9%) over the 12 months.
Tech stack
PostgreSQL: star schema, 9 reporting views (CTEs, window functions, `FILTER`, `STRING_AGG`)
Power BI: data model, DAX, drillthrough, bookmarks, conditional formatting, decomposition tree, waterfall, heatmap, map
DAX: 41 measures including MoM, effective service charge %, compliance %, risk score and action logic (see `powerbi/measures.md`)
Data model
```
dim_vendor ── dim_vendor_site ── dim_location
                   │
      ┌────────────┴─────────────┐
fact_vendor_monthly      fact_compliance_doc ── dim_doc_type
      │                          │               dim_status
      └──────────── dim_date ────┘
```
Table	Grain
`fact_vendor_monthly`	1 vendor site × 1 month (headcount, CTC, service charge, GST, total paid, mail status)
`fact_compliance_doc`	1 vendor site × 1 month × 1 document (status, challan or UTR date)
Design decisions:
Compliance % = Received ÷ (Received + Not Received); `N/A` documents are excluded from the base.
Effective service charge % = total service charge ÷ total CTC (a weighted ratio, not an average of percentages).
Headcount is a monthly snapshot, so it is never summed across months.
Terminated vendors get one `Closed` row in the month after exit; months with no deployment are `No Work`.
SQL views
View	Purpose
`vw_site_master`	Flat vendor + location + site dimension
`vw_vendor_monthly`	Monthly fact with dimensions and previous-month payment
`vw_compliance_detail`	Document-level detail with days late (PF/ESIC due on the 15th)
`vw_site_compliance_monthly`	Site-level compliance % and list of missing documents
`vw_vendor_compliance_monthly`	Vendor-level compliance and fully compliant sites
`vw_monthly_cost_summary`	Cost by vendor type with MoM % and fiscal YTD
`vw_vendor_lifecycle`	First and last active month, terminated or newly onboarded
`vw_challan_timeliness`	Late challan % and average days late
`vw_vendor_scorecard_latest`	Latest-month scorecard with ranks
Power BI features
Drillthrough from any vendor to the Vendor Scorecard
Bookmarks and a page-navigation menu
Vendor-type slicer buttons that filter every page
KPI cards with MoM indicator and conditional colour
Waterfall, decomposition tree, heatmap matrix, gauge, map and combo charts
Vendor risk score (50% compliance, 30% late challans, 20% reminders) with action recommendation
<!-- Add these lines only if you have built them:
- Fiscal YTD (Apr–Mar) measures
- Row-level security by region
- Published to Power BI Service with scheduled refresh
How to run
Create a database: `createdb vendor_dw`
Unzip `data/csv_files.zip` in the repository root so that a `csv/` folder sits next to `sql/`.
From the repository root, load the schema and data, then create the views:
```bash
   psql -d vendor_dw -f sql/schema.sql
   psql -d vendor_dw -f sql/views.sql
   ```
Open `powerbi/Vendor_Compliance_Dashboard.pbix` in Power BI Desktop and point the data source to your server and database (Transform data → Data source settings).
> `schema.sql` creates the tables in a schema called `vc`. If the report shows missing tables, either point Power BI to the `vc` schema or remove the `CREATE SCHEMA` and `SET search_path` lines to use `public`.
Repository structure
```
├── README.md
├── data/csv_files.zip          # synthetic dimension and fact tables
├── sql/
│   ├── schema.sql              # tables, keys, indexes, load commands
│   └── views.sql               # 9 reporting views
├── powerbi/
│   ├── Vendor_Compliance_Dashboard.pbix
│   └── measures.md             # all DAX measures with descriptions
├── docs/
│   └── Vendor_Compliance_Dashboard.pdf   # full dashboard preview
└── screenshots/                # one image per report page
```
Author
Ashutosh Kumar: payroll and vendor compliance professional moving into data analytics.
