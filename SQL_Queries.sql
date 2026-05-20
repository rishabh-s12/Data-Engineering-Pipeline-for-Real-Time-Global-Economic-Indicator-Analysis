/*GDP by Income Tier*/
SELECT 
    income_tier,
    COUNT(*) AS num_countries,
    ROUND(SUM(gdp_usd), 2) AS total_gdp
FROM (
    SELECT 
        gdp_usd,
        CASE 
            WHEN gdp_per_capita < 4000 THEN 'Low Income'
            WHEN gdp_per_capita < 10000 THEN 'Lower Middle Income'
            WHEN gdp_per_capita < 20000 THEN 'Upper Middle Income'
            ELSE 'High Income'
        END AS income_tier
    FROM dea_project_rishabh_processed1
    WHERE year = 2023
      AND gdp_per_capita IS NOT NULL
) t
GROUP BY income_tier
ORDER BY total_gdp DESC;


/* Avg GDP per Capita by population size */
SELECT 
    country_size,
    COUNT(*) AS num_countries,
    ROUND(AVG(gdp_per_capita), 2) AS avg_gdp_per_capita
FROM (
    SELECT 
        gdp_per_capita,
        CASE 
            WHEN population < 10000000 THEN 'Small (<10M)'
            WHEN population < 100000000 THEN 'Medium (10M-100M)'
            ELSE 'Large (>100M)'
        END AS country_size
    FROM dea_project_rishabh_processed1
    WHERE year = 2023
      AND population IS NOT NULL
      AND gdp_per_capita IS NOT NULL
) t
GROUP BY country_size
ORDER BY avg_gdp_per_capita DESC


-- Recovery % after Corona
SELECT 
    country_name,
    gdp_2019,
    gdp_2020,
    gdp_2022,
    ROUND(((gdp_2022 - gdp_2019) / gdp_2019) * 100, 2) AS recovery_pct_vs_2019
FROM (
    SELECT 
        country_name,
        MAX(CASE WHEN year = 2019 THEN gdp_usd END) AS gdp_2019,
        MAX(CASE WHEN year = 2020 THEN gdp_usd END) AS gdp_2020,
        MAX(CASE WHEN year = 2022 THEN gdp_usd END) AS gdp_2022
    FROM dea_project_rishabh_processed1
    GROUP BY country_name
) t
WHERE gdp_2019 IS NOT NULL
  AND gdp_2022 IS NOT NULL
ORDER BY recovery_pct_vs_2019 DESC
LIMIT 30

-- Top 10 Countries by GDP
SELECT 
    country_name,
    avg_gdp_trillion
FROM (
    SELECT 
        country_name,
        ROUND(AVG(gdp_usd) / 1e12, 3) AS avg_gdp_trillion,
        ROW_NUMBER() OVER (ORDER BY AVG(gdp_usd) DESC) AS rn
    FROM dea_project_rishabh_processed1
    WHERE year BETWEEN 2000 AND 2024
      AND gdp_usd IS NOT NULL
    GROUP BY country_name
) t
WHERE rn > 2 AND rn <= 12

/* GDP per capita per Year */
SELECT 
    country_name,
    year,
    population,
    gdp_per_capita,
    gdp_usd,
    population_quartile
FROM (
    SELECT 
        country_name,
        year,
        population,
        gdp_per_capita,
        gdp_usd,
        NTILE(4) OVER (ORDER BY population) AS population_quartile
    FROM dea_project_rishabh_processed1
    WHERE year = 2023
      AND population IS NOT NULL
) t
WHERE gdp_per_capita IS NOT NULL
ORDER BY population DESC;

/* GDP Growth Rate per year */
SELECT 
    country_name,
    year,
    gdp_usd,
    prev_gdp,
    ROUND(((gdp_usd - prev_gdp) / prev_gdp) * 100, 2) AS gdp_growth_rate_pct
FROM (
    SELECT 
        country_name,
        country_code,
        year,
        gdp_usd,
        LAG(gdp_usd) OVER (PARTITION BY country_code ORDER BY year) AS prev_gdp
    FROM dea_project_rishabh_processed1
) t
WHERE year BETWEEN 2000 AND 2024
  AND prev_gdp IS NOT NULL
ORDER BY country_name, year


