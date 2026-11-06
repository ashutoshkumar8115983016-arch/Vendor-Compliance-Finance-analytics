
DROP TABLE IF EXISTS dim_vendor;
CREATE TABLE dim_vendor(
	vendor_id INT PRIMARY KEY,
	vendor_name VARCHAR(35) NOT NULL,
	vendor_type VARCHAR(10) NOT NULL,
	CONSTRAINT vendor_check CHECK (vendor_type IN ('Manpower','Security','NAPS')), 
	contract_service_charge_pct NUMERIC(4,2)
);
ALTER TABLE dim_vendor
ALTER COLUMN vendor_id TYPE VARCHAR(5)

CREATE TABLE dim_location(	
	location_id VARCHAR(5) PRIMARY KEY,
	location_name VARCHAR(10),
	state VARCHAR(15),
	region VARCHAR(5),
	pt_applicable SMALLINT,
	lwf_applicable SMALLINT NOT NULL
);
ALTER TABLE dim_location
ALTER COLUMN location_name TYPE VARCHAR(15)

CREATE TABLE dim_vendor_site(
	site_id VARCHAR(5) PRIMARY KEY NOT NULL,
	vendor_id VARCHAR(5) NOT NULL,
	CONSTRAINT fk_vendor
	FOREIGN KEY(vendor_id)
	REFERENCES dim_vendor(vendor_id),
	location_id VARCHAR(5)NOT NULL,
	CONSTRAINT fk_location
	FOREIGN KEY(location_id)
	REFERENCES dim_location(location_id),
	site_label VARCHAR(20),
	start_date_key INT,
	end_date_key INT,
	is_active SMALLINT NOT NULL DEFAULT 1
);

CREATE TABLE dim_date (
    date_key       INT PRIMARY KEY,
    month_start    DATE NOT NULL,
    month_name     VARCHAR(10),
    month_no       SMALLINT,
    year           SMALLINT,
    quarter        CHAR(2),
    fiscal_year    VARCHAR(8),
    fiscal_quarter VARCHAR(4),
    month_sort     SMALLINT
);

ALTER TABLE dim_date
ALTER fiscal_year TYPE VARCHAR(10)

CREATE TABLE dim_doc_type (
    doc_type_id  SMALLINT PRIMARY KEY,
    doc_name     VARCHAR(50) NOT NULL,
    doc_category VARCHAR(20) NOT NULL,
    has_doc_date SMALLINT NOT NULL
);

CREATE TABLE dim_status (
    status_id   SMALLINT PRIMARY KEY,
    status_name VARCHAR(20) NOT NULL,
    is_received SMALLINT NOT NULL,
    counts_in_compliance_base SMALLINT NOT NULL
);


CREATE TABLE fact_vendor_monthly (
    fact_id               INT PRIMARY KEY,
    site_id               VARCHAR(5) NOT NULL,
	CONSTRAINT fk_vendor_site
	FOREIGN KEY(site_id)REFERENCES dim_vendor_site(site_id),
    date_key              INT NOT NULL,
	CONSTRAINT fk_date
	FOREIGN KEY(date_key)
	REFERENCES dim_date(date_key),
    mail_status           VARCHAR(15),
    vendor_status         VARCHAR(10) NOT NULL CHECK (vendor_status IN ('Active','Closed','No Work')),
    previous_headcount    INT,
    current_headcount     INT,
    monthly_ctc_amount    NUMERIC(14,0),
    service_charge_pct    NUMERIC(4,2),
    service_charge_amount NUMERIC(14,0),
    gst_on_service_charge NUMERIC(14,0),
    total_amount_paid     NUMERIC(14,0),
    open_points_remarks   TEXT,
    UNIQUE (site_id, date_key)
);

CREATE TABLE fact_compliance_doc (
    doc_fact_id INT PRIMARY KEY,
    site_id     VARCHAR(5) NOT NULL REFERENCES dim_vendor_site(site_id),
    date_key    INT NOT NULL REFERENCES dim_date(date_key),
    doc_type_id SMALLINT NOT NULL REFERENCES dim_doc_type(doc_type_id),
    status_id   SMALLINT NOT NULL REFERENCES dim_status(status_id),
    doc_date    DATE,
    UNIQUE (site_id, date_key, doc_type_id)
);

CREATE INDEX ix_fvm_date ON fact_vendor_monthly(date_key);
CREATE INDEX ix_fcd_site_date ON fact_compliance_doc(site_id, date_key);

SELECT * FROM dim_date
SELECT * FROM dim_doc_type
SELECT * FROM dim_loctaion
SELECT * FROM dim_status
SELECT * FROM dim_vendor
SELECT * FROM dim_vendor_site
SELECT * FROM fact_compliance_doc
SELECT * FROM fact_vendor_monthly
