use crowdfunding;

-- 1. CONVERT EPOCH DATE FIELDS TO NATURAL TIME
-- ============================================================

-- Created Date
SELECT
    ProjectID,
    created_at,
    FROM_UNIXTIME(created_at) AS created_date
FROM projects;

-- Deadline Date
SELECT
    ProjectID,
    deadline,
    FROM_UNIXTIME(deadline) AS deadline_date
FROM projects;

-- Updated Date
SELECT
    ProjectID,
    updated_at,
    FROM_UNIXTIME(updated_at) AS updated_date
FROM projects;

-- State Changed Date
SELECT
    ProjectID,
    state_changed_at,
    FROM_UNIXTIME(state_changed_at) AS state_changed_date
FROM projects;

-- Launched Date
SELECT
    ProjectID,
    launched_at,
    FROM_UNIXTIME(launched_at) AS launched_date
FROM projects;

-- Successful Date
-- successful_at is stored as text and may contain an empty string.
SELECT
    ProjectID,
    successful_at,
    CASE
        WHEN NULLIF(TRIM(successful_at), '') IS NOT NULL
        THEN FROM_UNIXTIME(CAST(successful_at AS UNSIGNED))
        ELSE NULL
    END AS successful_date
FROM projects;

-- All useful natural-time columns together
SELECT
    ProjectID,
    state,
    name,
    country,
    FROM_UNIXTIME(created_at) AS created_date,
    FROM_UNIXTIME(deadline) AS deadline_date,
    FROM_UNIXTIME(updated_at) AS updated_date,
    FROM_UNIXTIME(state_changed_at) AS state_changed_date,
    FROM_UNIXTIME(launched_at) AS launched_date,
    CASE
        WHEN NULLIF(TRIM(successful_at), '') IS NOT NULL
        THEN FROM_UNIXTIME(CAST(successful_at AS UNSIGNED))
        ELSE NULL
    END AS successful_date
FROM projects;


-- ============================================================
-- 2. BUILD CALENDAR TABLE
--    Calendar is based on Created Date, from minimum to maximum.
-- ============================================================

DROP TABLE IF EXISTS calendar;

CREATE TABLE calendar (
    calendar_date DATE PRIMARY KEY,
    Year INT,
    Monthno INT,
    Monthfullname VARCHAR(20),
    Quarter VARCHAR(2),
    YearMonth VARCHAR(8),
    Weekdayno INT,
    Weekdayname VARCHAR(20),
    FinancialMonth VARCHAR(5),
    FinancialQuarter VARCHAR(5)
);

INSERT INTO calendar
(
    calendar_date,
    `Year`,
    Monthno,
    Monthfullname,
    `Quarter`,
    YearMonth,
    Weekdayno,
    Weekdayname,
    FinancialMonth,
    FinancialQuarter
)

SELECT
    DATE_ADD(x.min_date, INTERVAL n.num DAY) AS calendar_date,

    YEAR(DATE_ADD(x.min_date, INTERVAL n.num DAY)) AS `Year`,

    MONTH(DATE_ADD(x.min_date, INTERVAL n.num DAY)) AS Monthno,

    MONTHNAME(DATE_ADD(x.min_date, INTERVAL n.num DAY)) AS Monthfullname,

    CONCAT(
        'Q',
        QUARTER(DATE_ADD(x.min_date, INTERVAL n.num DAY))
    ) AS `Quarter`,

    DATE_FORMAT(
        DATE_ADD(x.min_date, INTERVAL n.num DAY),
        '%Y-%b'
    ) AS YearMonth,

    WEEKDAY(
        DATE_ADD(x.min_date, INTERVAL n.num DAY)
    ) + 1 AS Weekdayno,

    DAYNAME(
        DATE_ADD(x.min_date, INTERVAL n.num DAY)
    ) AS Weekdayname,

    CONCAT(
        'FM',
        CASE
            WHEN MONTH(DATE_ADD(x.min_date, INTERVAL n.num DAY)) >= 4
            THEN MONTH(DATE_ADD(x.min_date, INTERVAL n.num DAY)) - 3
            ELSE MONTH(DATE_ADD(x.min_date, INTERVAL n.num DAY)) + 9
        END
    ) AS FinancialMonth,

    CONCAT(
        'FQ',
        CASE
            WHEN MONTH(DATE_ADD(x.min_date, INTERVAL n.num DAY)) BETWEEN 4 AND 6
                THEN 1

            WHEN MONTH(DATE_ADD(x.min_date, INTERVAL n.num DAY)) BETWEEN 7 AND 9
                THEN 2

            WHEN MONTH(DATE_ADD(x.min_date, INTERVAL n.num DAY)) BETWEEN 10 AND 12
                THEN 3

            ELSE 4
        END
    ) AS FinancialQuarter

FROM
(
    SELECT
        MIN(DATE(FROM_UNIXTIME(created_at))) AS min_date,
        MAX(DATE(FROM_UNIXTIME(created_at))) AS max_date
    FROM projects
) x

CROSS JOIN
(
    SELECT
        a.n
        + (b.n * 10)
        + (c.n * 100)
        + (d.n * 1000) AS num

    FROM
        (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL
         SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL
         SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) a

    CROSS JOIN
        (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL
         SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL
         SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) b

    CROSS JOIN
        (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL
         SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL
         SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) c

    CROSS JOIN
        (SELECT 0 AS n UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL
         SELECT 3 UNION ALL SELECT 4 UNION ALL SELECT 5 UNION ALL
         SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) d
) n

WHERE DATE_ADD(x.min_date, INTERVAL n.num DAY) <= x.max_date;


SELECT *
FROM calendar
ORDER BY calendar_date;


-- ============================================================
-- 3. DATA MODEL
-- ============================================================
-- The supplied SQL source contains the projects table only.
-- A complete multi-table model cannot be created without the
-- referenced Excel lookup files.
--
-- Recommended model when lookup tables are available:
--
--             Calendar
--                |
--                | calendar_date -> created_date
--                |
--             Projects
--                |
--       ---------------------
--       |         |         |
--   Category   Location   Creator
--
-- Example relationship validation queries:

SELECT
    COUNT(*) AS projects_without_category_id
FROM projects
WHERE category_id IS NULL;

SELECT
    COUNT(*) AS projects_without_location_id
FROM projects
WHERE location_id IS NULL;

SELECT
    COUNT(*) AS projects_without_creator_id
FROM projects
WHERE creator_id IS NULL;


-- ============================================================
-- 4. CONVERT GOAL AMOUNT INTO USD
--    Goal USD = Goal * Static USD Rate
-- ============================================================

SELECT
    ProjectID,
    name,
    goal,
    static_usd_rate,
    ROUND(goal * static_usd_rate, 2) AS goal_usd
FROM projects;

-- Optional: create a reusable view.
DROP VIEW IF EXISTS vw_projects_analysis;

CREATE VIEW vw_projects_analysis AS
SELECT
    ProjectID,
    state,
    name,
    country,
    creator_id,
    location_id,
    category_id,

    FROM_UNIXTIME(created_at) AS created_date,
    FROM_UNIXTIME(deadline) AS deadline_date,
    FROM_UNIXTIME(updated_at) AS updated_date,
    FROM_UNIXTIME(state_changed_at) AS state_changed_date,
    FROM_UNIXTIME(launched_at) AS launched_date,

    CASE
        WHEN NULLIF(TRIM(successful_at), '') IS NOT NULL
        THEN FROM_UNIXTIME(CAST(successful_at AS UNSIGNED))
        ELSE NULL
    END AS successful_date,

    goal,
    pledged,
    currency,
    usd_pledged,
    static_usd_rate,
    backers_count,
    ROUND(goal * static_usd_rate, 2) AS goal_usd
FROM projects;


-- ============================================================
-- 5. PROJECTS OVERVIEW KPI
-- ============================================================

-- 5.1 Total Number of Projects based on Outcome
SELECT
    state AS outcome,
    COUNT(*) AS total_projects
FROM projects
GROUP BY state
ORDER BY total_projects DESC;


-- 5.2 Total Number of Projects based on Location
SELECT
    country AS location,
    COUNT(*) AS total_projects
FROM projects
GROUP BY country
ORDER BY total_projects DESC;


-- 5.3 Total Number of Projects based on Category
SELECT
    category_id,
    COUNT(*) AS total_projects
FROM projects
GROUP BY category_id
ORDER BY total_projects DESC;


-- 5.4 Total Number of Projects created by Year
SELECT
    YEAR(FROM_UNIXTIME(created_at)) AS created_year,
    COUNT(*) AS total_projects
FROM projects
GROUP BY YEAR(FROM_UNIXTIME(created_at))
ORDER BY created_year;


-- 5.5 Total Number of Projects created by Quarter
SELECT
    YEAR(FROM_UNIXTIME(created_at)) AS created_year,
    QUARTER(FROM_UNIXTIME(created_at)) AS created_quarter,
    COUNT(*) AS total_projects
FROM projects
GROUP BY
    YEAR(FROM_UNIXTIME(created_at)),
    QUARTER(FROM_UNIXTIME(created_at))
ORDER BY
    created_year,
    created_quarter;

-- 5.6 Total Number of Projects created by Month
SELECT
    YEAR(FROM_UNIXTIME(created_at)) AS created_year,
    MONTH(FROM_UNIXTIME(created_at)) AS month_no,
    MONTHNAME(FROM_UNIXTIME(created_at)) AS month_name,
    COUNT(*) AS total_projects
FROM projects
GROUP BY
    YEAR(FROM_UNIXTIME(created_at)),
    MONTH(FROM_UNIXTIME(created_at)),
    MONTHNAME(FROM_UNIXTIME(created_at))
ORDER BY created_year, month_no;


-- 5.7 Year + Quarter + Month overview in one query
SELECT
    created_year,
    CONCAT('Q', quarter_no) AS quarter,
    month_no,
    month_name,
    total_projects
FROM
(
    SELECT
        YEAR(FROM_UNIXTIME(created_at)) AS created_year,
        QUARTER(FROM_UNIXTIME(created_at)) AS quarter_no,
        MONTH(FROM_UNIXTIME(created_at)) AS month_no,
        MONTHNAME(FROM_UNIXTIME(created_at)) AS month_name,
        COUNT(*) AS total_projects
    FROM projects
    GROUP BY
        YEAR(FROM_UNIXTIME(created_at)),
        QUARTER(FROM_UNIXTIME(created_at)),
        MONTH(FROM_UNIXTIME(created_at)),
        MONTHNAME(FROM_UNIXTIME(created_at))
) AS project_summary
ORDER BY
    created_year,
    quarter_no,
    month_no;


-- ============================================================
-- 6. SUCCESSFUL PROJECTS
-- ============================================================

-- 6.1 Amount Raised
-- usd_pledged is used because it represents the pledged amount in USD.
SELECT
    ROUND(SUM(usd_pledged), 2) AS amount_raised_usd
FROM projects
WHERE state = 'successful';


-- 6.2 Number of Backers
SELECT
    SUM(backers_count) AS total_backers
FROM projects
WHERE state = 'successful';


-- 6.3 Average Number of Days for Successful Projects
-- Duration is calculated from launched date to successful date.
SELECT
    ROUND(
        AVG(
            DATEDIFF(
                DATE(
                    CASE
                        WHEN NULLIF(TRIM(successful_at), '') IS NOT NULL
                        THEN FROM_UNIXTIME(CAST(successful_at AS UNSIGNED))
                    END
                ),
                DATE(FROM_UNIXTIME(launched_at))
            )
        ),
        2
    ) AS avg_days_for_successful_projects
FROM projects
WHERE state = 'successful'
  AND NULLIF(TRIM(successful_at), '') IS NOT NULL
  AND launched_at IS NOT NULL;


-- 6.4 Successful project details
SELECT
    ProjectID,
    name,
    category_id,
    country,
    backers_count,
    usd_pledged AS amount_raised_usd,
    ROUND(goal * static_usd_rate, 2) AS goal_usd,
    DATEDIFF(
        DATE(
            CASE
                WHEN NULLIF(TRIM(successful_at), '') IS NOT NULL
                THEN FROM_UNIXTIME(CAST(successful_at AS UNSIGNED))
            END
        ),
        DATE(FROM_UNIXTIME(launched_at))
    ) AS days_to_success
FROM projects
WHERE state = 'successful'
ORDER BY amount_raised_usd DESC;


-- ============================================================
-- 7. TOP SUCCESSFUL PROJECTS
-- ============================================================

-- 7.1 Top successful projects based on Number of Backers
SELECT
    ProjectID,
    name,
    category_id,
    country,
    backers_count,
    usd_pledged AS amount_raised_usd
FROM projects
WHERE state = 'successful'
ORDER BY backers_count DESC
LIMIT 10;


-- 7.2 Top successful projects based on Amount Raised
SELECT
    ProjectID,
    name,
    category_id,
    country,
    backers_count,
    usd_pledged AS amount_raised_usd
FROM projects
WHERE state = 'successful'
ORDER BY usd_pledged DESC
LIMIT 10;


-- 7.3 Top 10 with ranking by backers
SELECT
    ProjectID,
    name,
    backers_count,
    usd_pledged AS amount_raised_usd,
    DENSE_RANK() OVER (ORDER BY backers_count DESC) AS backer_rank
FROM projects
WHERE state = 'successful'
ORDER BY backer_rank
LIMIT 10;


-- 7.4 Top 10 with ranking by amount raised
SELECT
    ProjectID,
    name,
    backers_count,
    usd_pledged AS amount_raised_usd,
    DENSE_RANK() OVER (ORDER BY usd_pledged DESC) AS amount_raised_rank
FROM projects
WHERE state = 'successful'
ORDER BY amount_raised_rank
LIMIT 10;


-- ============================================================
-- 8. PERCENTAGE OF SUCCESSFUL PROJECTS
-- ============================================================

-- 8.1 Percentage of Successful Projects Overall
SELECT
    COUNT(*) AS total_projects,
    SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END)
        AS successful_projects,
    ROUND(
        100.0 * SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS successful_percentage
FROM projects;


-- 8.2 Percentage of Successful Projects by Category
SELECT
    category_id,
    COUNT(*) AS total_projects,
    SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END)
        AS successful_projects,
    ROUND(
        100.0 * SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS successful_percentage
FROM projects
GROUP BY category_id
ORDER BY successful_percentage DESC;


-- 8.3 Percentage of Successful Projects by Year
SELECT
    YEAR(FROM_UNIXTIME(created_at)) AS created_year,
    COUNT(*) AS total_projects,
    SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END)
        AS successful_projects,
    ROUND(
        100.0 * SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS successful_percentage
FROM projects
GROUP BY YEAR(FROM_UNIXTIME(created_at))
ORDER BY created_year;


-- 8.4 Percentage of Successful Projects by Month
SELECT
    YEAR(FROM_UNIXTIME(created_at)) AS created_year,
    MONTH(FROM_UNIXTIME(created_at)) AS month_no,
    MONTHNAME(FROM_UNIXTIME(created_at)) AS month_name,
    COUNT(*) AS total_projects,
    SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END)
        AS successful_projects,
    ROUND(
        100.0 * SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS successful_percentage
FROM projects
GROUP BY
    YEAR(FROM_UNIXTIME(created_at)),
    MONTH(FROM_UNIXTIME(created_at)),
    MONTHNAME(FROM_UNIXTIME(created_at))
ORDER BY created_year, month_no;


-- 8.5 Percentage of Successful Projects by Year and Quarter
SELECT
    YEAR(FROM_UNIXTIME(created_at)) AS created_year,
	QUARTER(FROM_UNIXTIME(created_at)) AS quarter,
    COUNT(*) AS total_projects,
    SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END)
        AS successful_projects,
    ROUND(
        100.0 * SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS successful_percentage
FROM projects
GROUP BY
    YEAR(FROM_UNIXTIME(created_at)),
    QUARTER(FROM_UNIXTIME(created_at))
ORDER BY created_year, quarter;


-- ============================================================
-- 8.6 SUCCESS RATE BY GOAL RANGE
--     Goal ranges are chosen for analysis.
-- ============================================================

WITH goal_ranges AS (
    SELECT
        *,
        ROUND(goal * static_usd_rate, 2) AS goal_usd
    FROM projects
)
SELECT
    CASE
        WHEN goal_usd < 1000 THEN '< $1K'
        WHEN goal_usd < 5000 THEN '$1K - $4.99K'
        WHEN goal_usd < 10000 THEN '$5K - $9.99K'
        WHEN goal_usd < 25000 THEN '$10K - $24.99K'
        WHEN goal_usd < 50000 THEN '$25K - $49.99K'
        WHEN goal_usd < 100000 THEN '$50K - $99.99K'
        ELSE '$100K+'
    END AS goal_range,
    COUNT(*) AS total_projects,
    SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END)
        AS successful_projects,
    ROUND(
        100.0 * SUM(CASE WHEN state = 'successful' THEN 1 ELSE 0 END)
        / NULLIF(COUNT(*), 0),
        2
    ) AS successful_percentage
FROM goal_ranges
GROUP BY
    CASE
        WHEN goal_usd < 1000 THEN '< $1K'
        WHEN goal_usd < 5000 THEN '$1K - $4.99K'
        WHEN goal_usd < 10000 THEN '$5K - $9.99K'
        WHEN goal_usd < 25000 THEN '$10K - $24.99K'
        WHEN goal_usd < 50000 THEN '$25K - $49.99K'
        WHEN goal_usd < 100000 THEN '$50K - $99.99K'
        ELSE '$100K+'
    END
ORDER BY MIN(goal_usd);


-- ============================================================
-- 8.7 SUCCESSFUL PROJECTS BY GOAL RANGE ONLY
-- ============================================================

WITH goal_ranges AS (
    SELECT
        *,
        ROUND(goal * static_usd_rate, 2) AS goal_usd
    FROM projects
)
SELECT
    CASE
        WHEN goal_usd < 1000 THEN '< $1K'
        WHEN goal_usd < 5000 THEN '$1K - $4.99K'
        WHEN goal_usd < 10000 THEN '$5K - $9.99K'
        WHEN goal_usd < 25000 THEN '$10K - $24.99K'
        WHEN goal_usd < 50000 THEN '$25K - $49.99K'
        WHEN goal_usd < 100000 THEN '$50K - $99.99K'
        ELSE '$100K+'
    END AS goal_range,
    COUNT(*) AS successful_projects
FROM goal_ranges
WHERE state = 'successful'
GROUP BY
    CASE
        WHEN goal_usd < 1000 THEN '< $1K'
        WHEN goal_usd < 5000 THEN '$1K - $4.99K'
        WHEN goal_usd < 10000 THEN '$5K - $9.99K'
        WHEN goal_usd < 25000 THEN '$10K - $24.99K'
        WHEN goal_usd < 50000 THEN '$25K - $49.99K'
        WHEN goal_usd < 100000 THEN '$50K - $99.99K'
        ELSE '$100K+'
    END
ORDER BY MIN(goal_usd);


-- ============================================================
-- OPTIONAL: QUERIES FOR POWER BI / REPORTING DATASET
-- ============================================================

-- One clean dataset containing all major analysis fields.
SELECT
    p.ProjectID,
    p.state AS outcome,
    p.name,
    p.country,
    p.creator_id,
    p.location_id,
    p.category_id,

    FROM_UNIXTIME(p.created_at) AS created_date,
    FROM_UNIXTIME(p.deadline) AS deadline_date,
    FROM_UNIXTIME(p.updated_at) AS updated_date,
    FROM_UNIXTIME(p.state_changed_at) AS state_changed_date,
    FROM_UNIXTIME(p.launched_at) AS launched_date,

    CASE
        WHEN NULLIF(TRIM(p.successful_at), '') IS NOT NULL
        THEN FROM_UNIXTIME(CAST(p.successful_at AS UNSIGNED))
        ELSE NULL
    END AS successful_date,

    p.goal,
    p.pledged,
    p.currency,
    p.usd_pledged,
    p.static_usd_rate,
    p.backers_count,

    ROUND(p.goal * p.static_usd_rate, 2) AS goal_usd,

    CASE
        WHEN p.state = 'successful'
             AND NULLIF(TRIM(p.successful_at), '') IS NOT NULL
             AND p.launched_at IS NOT NULL
        THEN DATEDIFF(
            DATE(FROM_UNIXTIME(CAST(p.successful_at AS UNSIGNED))),
            DATE(FROM_UNIXTIME(p.launched_at))
        )
        ELSE NULL
    END AS days_to_success,

    YEAR(FROM_UNIXTIME(p.created_at)) AS created_year,
    MONTH(FROM_UNIXTIME(p.created_at)) AS created_month_no,
    MONTHNAME(FROM_UNIXTIME(p.created_at)) AS created_month_name,
    CONCAT('Q', QUARTER(FROM_UNIXTIME(p.created_at))) AS created_quarter
FROM projects p;
