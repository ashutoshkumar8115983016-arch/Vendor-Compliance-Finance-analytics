-- =====================================================================
-- Vendor Compliance Analytics | PostgreSQL views (run after schema.sql)
-- Layer: base tables (dim_/fact_)  ->  vw_ views  ->  Power BI
-- =====================================================================
SET search_path TO vc;

-- 1) Site master: vendor + location + site in ONE flat dimension --------
CREATE OR REPLACE VIEW vw_site_master AS
SELECT s.site_id, s.site_label,
       v.vendor_id, v.vendor_name, v.vendor_type,
       l.location_id, l.location_name, l.state, l.region,
       s.start_date_key, s.end_date_key, s.is_active
FROM dim_vendor_site s
JOIN dim_vendor   v ON v.vendor_id   = s.vendor_id
JOIN dim_location l ON l.location_id = s.location_id;

SELECT * FROM vw_site_master
SELECT COUNT(vendor_name) FROM vw_site_master

-- 2) Monthly vendor fact enriched with dims + MoM helpers ---------------
CREATE OR REPLACE VIEW vw_vendor_monthly AS
SELECT f.fact_id, f.site_id, f.date_key,
       d.month_start, d.month_name, d.fiscal_year, d.fiscal_quarter,
       m.vendor_id, m.vendor_name, m.vendor_type, m.location_name, m.state, m.region,
       f.vendor_status, f.mail_status,
       f.previous_headcount, f.current_headcount,
       f.current_headcount - f.previous_headcount                        AS headcount_change,
       f.monthly_ctc_amount, f.service_charge_pct, f.service_charge_amount,
       f.gst_on_service_charge, f.total_amount_paid,
       LAG(f.total_amount_paid) OVER (PARTITION BY f.site_id ORDER BY f.date_key) AS prev_month_total_paid,
       f.open_points_remarks
FROM fact_vendor_monthly f
JOIN dim_date d        ON d.date_key = f.date_key
JOIN vw_site_master m  ON m.site_id  = f.site_id;
SELECT * FROM vw_vendor_monthly


-- 3) Document-level detail (one row per site x month x document) --------
CREATE OR REPLACE VIEW vw_compliance_detail AS
SELECT c.doc_fact_id, c.site_id, c.date_key, d.month_start, d.month_name, d.fiscal_year,
       m.vendor_id, m.vendor_name, m.vendor_type, m.location_name, m.state, m.region,
       t.doc_type_id, t.doc_name, t.doc_category,
       s.status_name, s.is_received, s.counts_in_compliance_base,
       c.doc_date,
       -- statutory due date = 15th of the following month (PF / ESIC challans)
       CASE WHEN t.doc_type_id IN (1,3) AND c.doc_date IS NOT NULL
            THEN GREATEST(c.doc_date - (date_trunc('month', d.month_start) + INTERVAL '14 days' + INTERVAL '1 month')::date, 0)
       END AS days_late
FROM fact_compliance_doc c
JOIN dim_date d        ON d.date_key     = c.date_key
JOIN dim_doc_type t    ON t.doc_type_id  = c.doc_type_id
JOIN dim_status s      ON s.status_id    = c.status_id
JOIN vw_site_master m  ON m.site_id      = c.site_id;
SELECT * FROM vw_compliance_detail

-- 4) Site-level compliance per month (N/A removed from the base) --------
CREATE OR REPLACE VIEW vw_site_compliance_monthly AS
SELECT site_id, date_key, month_start, month_name, fiscal_year,
       vendor_id, vendor_name, vendor_type, location_name, state, region,
       SUM(counts_in_compliance_base)                                   AS required_docs,
       SUM(is_received)                                                 AS received_docs,
       SUM(counts_in_compliance_base) - SUM(is_received)                AS missing_docs,
       ROUND(100.0 * SUM(is_received) / NULLIF(SUM(counts_in_compliance_base),0), 1) AS compliance_pct,
       STRING_AGG(doc_name, ', ' ORDER BY doc_type_id) FILTER (WHERE status_name = 'Not Received') AS missing_doc_list
FROM vw_compliance_detail
GROUP BY site_id, date_key, month_start, month_name, fiscal_year,
         vendor_id, vendor_name, vendor_type, location_name, state, region;
SELECT * FROM vw_site_compliance_monthly


-- 5) Vendor-level compliance per month ---------------------------------
CREATE OR REPLACE VIEW vw_vendor_compliance_monthly AS
SELECT vendor_id, vendor_name, vendor_type, date_key, month_start, month_name, fiscal_year,
       COUNT(*)                                                       AS sites,
       COUNT(*) FILTER (WHERE missing_docs = 0)                       AS fully_compliant_sites,
       SUM(required_docs)                                             AS required_docs,
       SUM(received_docs)                                             AS received_docs,
       ROUND(100.0 * SUM(received_docs) / NULLIF(SUM(required_docs),0), 1) AS compliance_pct
FROM vw_site_compliance_monthly
GROUP BY vendor_id, vendor_name, vendor_type, date_key, month_start, month_name, fiscal_year;

SELECT * FROM vw_vendor_compliance_monthly


-- 6) Cost summary by month x vendor type: MoM % and fiscal YTD ----------
CREATE OR REPLACE VIEW vw_monthly_cost_summary AS
WITH base AS (
    SELECT vendor_type, fiscal_year, month_start, month_name,
           SUM(current_headcount)       AS headcount,
           SUM(monthly_ctc_amount)      AS ctc,
           SUM(service_charge_amount)   AS service_charge,
           SUM(gst_on_service_charge)   AS gst,
           SUM(total_amount_paid)       AS total_paid
    FROM vw_vendor_monthly
    WHERE vendor_status = 'Active'
    GROUP BY vendor_type, fiscal_year, month_start, month_name
)
SELECT b.*,
       ROUND(100.0 * service_charge / NULLIF(ctc,0), 2)                         AS effective_sc_pct,
       ROUND(total_paid::numeric / NULLIF(headcount,0), 0)                      AS cost_per_head,
       LAG(total_paid) OVER w                                                   AS prev_month_paid,
       ROUND(100.0 * (total_paid - LAG(total_paid) OVER w)
             / NULLIF(LAG(total_paid) OVER w,0), 2)                             AS mom_pct,
       SUM(total_paid) OVER (PARTITION BY vendor_type, fiscal_year ORDER BY month_start) AS fiscal_ytd_paid
FROM base b
WINDOW w AS (PARTITION BY vendor_type ORDER BY month_start);

SELECT * FROM vw_monthly_cost_summary


-- 7) Vendor lifecycle: onboarded / terminated / continuous --------------
CREATE OR REPLACE VIEW vw_vendor_lifecycle AS
SELECT vendor_id, vendor_name, vendor_type,
       MIN(month_start) FILTER (WHERE vendor_status = 'Active')       AS first_active_month,
       MAX(month_start) FILTER (WHERE vendor_status = 'Active')       AS last_active_month,
       COUNT(*) FILTER (WHERE vendor_status = 'Active')               AS active_site_months,
       SUM(total_amount_paid)                                         AS lifetime_paid,
       CASE WHEN MAX(month_start) FILTER (WHERE vendor_status = 'Active') < (SELECT MAX(month_start) FROM dim_date)
                 THEN 'Terminated'
            WHEN MIN(month_start) FILTER (WHERE vendor_status = 'Active') > (SELECT MIN(month_start) FROM dim_date)
                 THEN 'Newly Onboarded'
            ELSE 'Continuous' END                                     AS lifecycle_status
FROM vw_vendor_monthly
GROUP BY vendor_id, vendor_name, vendor_type;

SELECT * FROM vw_vendor_lifecycle

-- 8) Challan timeliness (PF + ESIC) per vendor x month ------------------
CREATE OR REPLACE VIEW vw_challan_timeliness AS
SELECT vendor_id, vendor_name, vendor_type, date_key, month_start, month_name,
       COUNT(*)                                          AS challans_received,
       COUNT(*) FILTER (WHERE days_late > 0)             AS late_challans,
       ROUND(100.0 * COUNT(*) FILTER (WHERE days_late > 0) / COUNT(*), 1) AS late_pct,
       ROUND(AVG(days_late), 1)                          AS avg_days_late
FROM vw_compliance_detail
WHERE doc_type_id IN (1,3) AND doc_date IS NOT NULL
GROUP BY vendor_id, vendor_name, vendor_type, date_key, month_start, month_name;

SELECT * FROM vw_challan_timeliness


-- 9) Latest-month vendor scorecard (feeds the drillthrough page) --------
CREATE OR REPLACE VIEW vw_vendor_scorecard_latest AS
WITH latest AS (SELECT MAX(date_key) AS dk FROM fact_vendor_monthly),
cost AS (
    SELECT vendor_id, vendor_name, vendor_type,
           SUM(current_headcount) AS headcount, SUM(total_amount_paid) AS total_paid,
           ROUND(100.0*SUM(service_charge_amount)/NULLIF(SUM(monthly_ctc_amount),0),2) AS effective_sc_pct
    FROM vw_vendor_monthly WHERE date_key = (SELECT dk FROM latest) AND vendor_status='Active'
    GROUP BY vendor_id, vendor_name, vendor_type)
SELECT c.*, k.sites, k.fully_compliant_sites, k.compliance_pct,
       RANK() OVER (ORDER BY k.compliance_pct DESC) AS compliance_rank,
       RANK() OVER (ORDER BY c.total_paid DESC)     AS spend_rank
FROM cost c
JOIN vw_vendor_compliance_monthly k
  ON k.vendor_id = c.vendor_id AND k.date_key = (SELECT dk FROM latest);

SELECT * FROM vw_vendor_scorecard_latest


CREATE OR REPLACE VIEW vw_compliance_detail AS
INSERT INTO dim_date (date_key, month_start, month_name, month_no, year, quarter, fiscal_year, fiscal_quarter, month_sort)
SELECT 
    TO_CHAR(d, 'YYYYMMDD')::INT AS date_key,
    d AS month_start,
    TO_CHAR(d, 'Mon''YY') AS month_name,
    EXTRACT(MONTH FROM d)::SMALLINT AS month_no,
    EXTRACT(YEAR FROM d)::SMALLINT AS year,
    'Q' || EXTRACT(QUARTER FROM d)::TEXT AS quarter,
    CASE 
        WHEN EXTRACT(MONTH FROM d) >= 4 THEN 'FY' || EXTRACT(YEAR FROM d) || '-' || RIGHT((EXTRACT(YEAR FROM d)+1)::TEXT, 2)
        ELSE 'FY' || (EXTRACT(YEAR FROM d)-1) || '-' || RIGHT(EXTRACT(YEAR FROM d)::TEXT, 2)
    END AS fiscal_year,
    CASE 
        WHEN EXTRACT(MONTH FROM d) IN (4,5,6) THEN 'FQ1'
        WHEN EXTRACT(MONTH FROM d) IN (7,8,9) THEN 'FQ2'
        WHEN EXTRACT(MONTH FROM d) IN (10,11,12) THEN 'FQ3'
        ELSE 'FQ4'
    END AS fiscal_quarter,
    ROW_NUMBER() OVER (ORDER BY d)::SMALLINT AS month_sort
FROM generate_series('2025-09-01'::DATE, '2026-08-31'::DATE, '1 day') AS d
ON CONFLICT (date_key) DO NOTHING;

