CREATE DATABASE IF NOT EXISTS weather;

USE weather;

/* 
 * Zu Beginn alle existierenden Funktionen löschen hat den Vorteil,
 * dass wenn man die Funktion ändert, die Funktionen nach dem Löschen 
 * automatisch mit den neuen Änderungen erstellt werden, wenn man den
 * entsprechenden Abschnitt nochmals ausführt.
 * 
 * Bei Nutzung mit DBeaver gilt zu beachten, dass man alle Zeilen
 * von delimiter // bis delimiter ; gleichzeitig markieren muss und anschließend
 * auf Skript ausführen klicken muss. Anderenfalls werden die Funktionen nicht
 * korrekt erstellt und können im weiteren Verlauf nicht verwendet werden!
 */
DROP FUNCTION IF EXISTS get_correlation_category;
DROP FUNCTION IF EXISTS get_uv_risk;
DROP FUNCTION IF EXISTS get_season;
DROP FUNCTION IF EXISTS get_month;
DROP FUNCTION IF EXISTS get_gb_defra_category;

/* 
 * Hinzufügen einer ID Spalte als PRIMARY KEY
 */
ALTER TABLE GlobalWeatherRepository ADD COLUMN id INTEGER PRIMARY KEY AUTO_INCREMENT FIRST;

/* 
 * Anzahl Datensätze für das Jahr 2025 erfassen
 * Sollte > 32000 Datensätze sein
 */
SELECT COUNT(*) AS ct_lines FROM GlobalWeatherRepository gwr 
WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025;

DELIMITER //

/*
 * Funktion zur Kategorisierung eines Korrelationswertes
 */
CREATE FUNCTION get_correlation_category(value DECIMAL(4, 2))
RETURNS VARCHAR(30)
DETERMINISTIC
BEGIN 
    IF ABS(value) >= 0.5 THEN  -- ABS verwendet den Betrag der Zahl, also ohne Beachtung des Vorzeichens
        RETURN 'Starke Korrelation';
    ELSEIF ABS(value) >= 0.3 THEN
        RETURN 'Mittlere Korrelation';
    ELSEIF ABS(value) >= 0.1 THEN
        RETURN 'Geringe Korrelation';
    ELSE
        RETURN 'Keine Korrelation';
    END IF;
END //

/*
 * Funktion zur Einschätzung des Sonnenbrandrisikos anhand der gemessenen UV Strahlung
 */
CREATE FUNCTION get_uv_risk(value INTEGER)
RETURNS VARCHAR(30)
DETERMINISTIC
BEGIN
	IF value >= 11 THEN
		RETURN 'Extremes Risiko';
	ELSEIF value BETWEEN 8 AND 10 THEN 
		RETURN 'Sehr hohes Risiko';
	ELSEIF value BETWEEN 6 AND 7 THEN 
		RETURN 'Hohes Risiko';
	ELSEIF value BETWEEN 3 AND 5 THEN 
		RETURN 'Mittleres Risiko';
	ELSEIF value BETWEEN 1 AND 2 THEN 
		RETURN 'Geringes Risiko';
	ELSE 
		RETURN 'Kein Risiko';
	END IF; 
END //

/* 
 * Funktion zur Einteilung der Daten in Quartale
 * Achtung: Zeitraum startet am 21. Dezember für Winter
 * und endet mit dem 20. Dezember für Herbst, da ich mich
 * an den kalendarischen Anfängen orientiere!
 */
CREATE FUNCTION get_season(value DATE)
RETURNS VARCHAR(30)
DETERMINISTIC
BEGIN
	IF value BETWEEN DATE('2024-12-21') AND DATE('2025-03-19') THEN 
		RETURN 'Winter';
	ELSEIF value BETWEEN DATE('2025-03-20') AND DATE('2025-06-20') THEN
		RETURN 'Frühling';
	ELSEIF value BETWEEN DATE('2025-06-21') AND DATE('2025-09-21') THEN
		RETURN 'Sommer';
	ELSEIF value BETWEEN DATE('2025-09-22') AND DATE('2025-12-20') THEN
		RETURN 'Herbst';
	ELSE
		RETURN NULL;
	END IF;
END //

/* 
 * Funktion zur Ausgabe der Monate als Text
 */
CREATE FUNCTION get_month(value DATE) 
RETURNS VARCHAR(30)
DETERMINISTIC 
BEGIN
	SET lc_time_names = 'de_DE';  -- Rückgabe der deutschen Namen für Monate
	RETURN DATE_FORMAT(value, '%M');
END //

/*
 * Funktion zur Kategorisierung des Britischen Luftqualitätsindex
 */
CREATE FUNCTION get_gb_defra_category(value DOUBLE) 
RETURNS VARCHAR(30)
DETERMINISTIC
BEGIN 
	IF value BETWEEN 7.5 AND 10.0 THEN 
		RETURN 'sehr schlecht';
	ELSEIF value BETWEEN 5.0 AND 7.4 THEN 
		RETURN 'schlecht';
	ELSEIF value BETWEEN 2.5 AND 4.9 THEN 
		RETURN 'mittel';
	ELSEIF value BETWEEN 0.0 AND 2.4 THEN
		RETURN 'gut';
	END IF;
END //

DELIMITER ;

/*
 * Funktionstests
 */
SELECT get_correlation_category(0.5)  AS correlation_category;  -- Erwartet: 'Starke Korrelation'
SELECT get_correlation_category(0.3)  AS correlation_category;  -- Erwartet: 'Mittlere Korrelation'
SELECT get_correlation_category(0.1)  AS correlation_category;  -- Erwartet: 'Geringe Korrelation'
SELECT get_correlation_category(-0.1) AS correlation_category;  -- Erwartet: 'Geringe Korrelation'
SELECT get_correlation_category(-0.3) AS correlation_category;  -- Erwartet: 'Mittlere Korrelation'
SELECT get_correlation_category(-0.5) AS correlation_category;  -- Erwartet: 'Starke Korrelation'

SELECT get_uv_risk(7) AS uv_risk_level;       -- Erwartet: 'Hohes Risiko'

SELECT get_season('2024-12-21') AS season;    -- Erwartet: 'Winter'
SELECT get_season('2024-12-20') AS season;    -- Erwartet: NULL

SELECT get_month('2025-01-04') AS `month`;    -- Erwartet: 'Januar'
SELECT get_month('2025-03-20') AS `month`;    -- Erwartet: 'März'
SELECT get_month('2024-12-21') AS `month`;    -- Erwartet: 'Dezember'

SELECT get_gb_defra_category(5) AS category;  -- Erwartet: 'schlecht'

/*
 * Mit den folgenden Abfragen verschaffe ich mir einen grundsätzlichen Überblick über 
 * die vorhandenen Daten in der Datenbanktabelle
 */
SELECT gwr.country, gwr.timezone FROM GlobalWeatherRepository gwr
GROUP BY gwr.country, gwr.timezone
ORDER BY gwr.timezone, gwr.country;

SELECT DISTINCT gwr.country, COUNT(gwr.country) AS ct_days
FROM GlobalWeatherRepository gwr 
GROUP BY gwr.country;

/* 
 * Liste alle Länder auf, die vollständige Daten für das Jahr 2025 enthalten
 */
CREATE OR REPLACE VIEW v_countries_with_full_2025 AS
SELECT DISTINCT gwr.country, gwr.timezone, COUNT(gwr.country) AS ct_days
FROM GlobalWeatherRepository gwr 
WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025
GROUP BY gwr.country, gwr.timezone
HAVING COUNT(gwr.country) = 365
ORDER BY gwr.country; 

CREATE OR REPLACE VIEW pbi_countries_with_full_2025 AS
WITH
tb_countries_2025 AS (
	SELECT DISTINCT gwr.country, 
	gwr.location_name,
	gwr.timezone,
	gwr.latitude, 
	gwr.longitude,
	gwr.temperature_celsius,
	gwr.feels_like_celsius,
	gwr.wind_kph,
	gwr.gust_kph,
	gwr.wind_direction,
	gwr.pressure_mb,
	gwr.precip_mm,
	gwr.humidity,
	gwr.visibility_km,
	gwr.air_quality_carbon_monoxide,
	gwr.air_quality_ozone,
	gwr.air_quality_nitrogen_dioxide,
	gwr.air_quality_sulphur_dioxide,
	gwr.`air_quality_pm2.5`,
	gwr.`air_quality_pm10`,
	gwr.`air_quality_us-epa-index`,
	gwr.`air_quality_gb-defra-index`,
	gwr.cloud,
	gwr.uv_index,
	gwr.last_updated,
	get_season(DATE(gwr.last_updated)) AS season,
	get_month(DATE(gwr.last_updated)) AS `month`,
	EXTRACT(MONTH FROM gwr.last_updated) AS month_number
	FROM GlobalWeatherRepository gwr
	WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025
	ORDER BY gwr.country, gwr.last_updated
)
SELECT *
FROM tb_countries_2025
WHERE country IN (
    SELECT country
    FROM tb_countries_2025
    GROUP BY country, timezone
    HAVING COUNT(*) = 365
);

SELECT DISTINCT country, timezone FROM pbi_countries_with_full_2025;

/*
 * Zeige alle Länder innerhalb der europäischen Zeitzone, die vollständige Daten
 * für das Jahr 2025 enthalten
 */
SELECT DISTINCT gwr.country, gwr.timezone, COUNT(gwr.country) AS ct_days
FROM GlobalWeatherRepository gwr 
WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025
AND gwr.timezone LIKE '%europe%'
GROUP BY gwr.country, gwr.timezone
HAVING COUNT(gwr.country) = 365
ORDER BY gwr.country; 

SELECT COUNT(*) AS ct_days FROM GlobalWeatherRepository gwr 
WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025
AND gwr.location_name LIKE '%berlin%';

/*
 * Durchschnittliche Wetterbedingungen hinsichtlich Zeitzonen und Länder 2025
 * Sortiert wird nach Ländern in der europäischen Zeitzone;
 * innerhalb der Zeitzonen wird alphabetisch aufsteigend nach Land sortiert
 * 
 * Die Abfrage wird als VIEW v_grouped_timezones abgespeichert, um die Daten nicht
 * bei jeder Abfrage neu filtern zu müssen.
 */
CREATE OR REPLACE VIEW v_grouped_timezones AS 
SELECT cwf.country, 
cwf.timezone, 
ROUND(AVG(cwf.temperature_celsius), 2) AS avg_temperature_celsius,
ROUND(AVG(cwf.wind_kph)) AS avg_wind_kph,
ROUND(AVG(cwf.gust_kph)) AS avg_gusts_kph,
ROUND(AVG(cwf.pressure_mb), 1) AS avg_pressure_millibars,
ROUND(AVG(cwf.humidity), 2) AS avg_percentage_humidity,
ROUND(AVG(cwf.visibility_km)) AS avg_visibility_km,
ROUND(AVG(cwf.cloud), 2) AS avg_percentage_cloud_cover,
ROUND(AVG(cwf.feels_like_celsius), 2) AS avg_feels_like_celsius,
ROUND(AVG(cwf.uv_index), 1) AS avg_uv_index
FROM pbi_countries_with_full_2025 cwf
WHERE EXTRACT(YEAR FROM cwf.last_updated) = 2025
GROUP BY cwf.country, cwf.timezone
ORDER BY 
CASE 
	WHEN cwf.timezone LIKE '%europe%' THEN 0
	ELSE 1
END, cwf.country, cwf.timezone;

CREATE OR REPLACE VIEW pbi_european_timezone_2025 AS
SELECT * FROM v_grouped_timezones gt
WHERE gt.timezone LIKE '%europe%';


/* ---------------------------------------------------
 * Analysen deutschlandweit und europaweit - Aufgabe 1
 -------------------------------------------------- */


/* 
 * Erstellen einer VIEW, die alle Wetterdaten für das Jahr 2025 in Deutschland speichert
 * Verwendung für Analysen, die sich auf die Monate oder das gesamte Jahr beziehen
 */
CREATE OR REPLACE VIEW v_weather_germany_2025 AS (
	SELECT cwf.location_name,
	cwf.country,
	cwf.temperature_celsius,
	cwf.feels_like_celsius,
	cwf.wind_kph,
	cwf.gust_kph,
	cwf.wind_direction,
	cwf.pressure_mb,
	cwf.precip_mm,
	cwf.humidity,
	cwf.visibility_km,
	cwf.air_quality_carbon_monoxide,
	cwf.air_quality_ozone,
	cwf.air_quality_nitrogen_dioxide,
	cwf.air_quality_sulphur_dioxide,
	cwf.`air_quality_us-epa-index`,
	cwf.`air_quality_gb-defra-index`,
	cwf.cloud,
	cwf.last_updated,
	get_month(DATE(cwf.last_updated)) AS `month`,
	EXTRACT(MONTH FROM cwf.last_updated) AS month_number
	FROM pbi_countries_with_full_2025 cwf
	WHERE EXTRACT(YEAR FROM cwf.last_updated) = 2025
	AND cwf.location_name LIKE '%berlin%'
	ORDER BY cwf.last_updated
);

CREATE OR REPLACE VIEW pbi_weather_germany_2025 AS (
	SELECT * FROM v_weather_germany_2025
);

/* 
 * Erstellen einer VIEW, die alle Wetterdaten im Zeitraum 21.12.2024 bis 20.12.2025 in Deutschland speichert
 * Verwendung ausschließlich für Analysen, die auf die Saison bezogen sind
 */
CREATE OR REPLACE VIEW v_weather_germany_seasons AS (
	SELECT gwr.location_name,
	gwr.country,
	gwr.temperature_celsius,
	gwr.feels_like_celsius,
	gwr.wind_kph,
	gwr.gust_kph,
	gwr.wind_direction,
	gwr.pressure_mb,
	gwr.precip_mm,
	gwr.humidity,
	gwr.visibility_km,
	gwr.air_quality_carbon_monoxide,
	gwr.air_quality_ozone,
	gwr.air_quality_nitrogen_dioxide,
	gwr.air_quality_sulphur_dioxide,
	gwr.cloud,
	gwr.last_updated,
	get_season(DATE(gwr.last_updated)) AS season,
	get_month(DATE(gwr.last_updated)) AS `month`,
	EXTRACT(MONTH FROM gwr.last_updated) AS month_number
	FROM GlobalWeatherRepository gwr
	WHERE DATE(gwr.last_updated) BETWEEN DATE('2024-12-21') AND DATE('2025-12-20')
	AND gwr.location_name LIKE '%berlin%'
	ORDER BY gwr.last_updated
);

CREATE OR REPLACE VIEW pbi_weather_germany_with_seasons AS
SELECT * FROM v_weather_germany_seasons;

SELECT * FROM pbi_weather_germany_with_seasons;

/*
 * Finde
 * - die Anzahl sonniger Tage (cloud < 50) und kein Niederschlag
 * - die Anzahl bewölkter Tage (cloud >= 50) und kein Niederschlag
 * - die Anzahl Tage mit Niederschlag (precip_mm > 0)
 * 2025 IN Deutschland (Berlin)
 */
WITH 
ct_sunny_days AS (
	SELECT COUNT(*) AS sunny_days 
	FROM v_weather_germany_2025 vwg 
	WHERE vwg.cloud < 50  -- Bewölkung kleiner 50%
	AND NOT vwg.precip_mm > 0.0  -- und kein Niederschlag
), 
ct_cloudy_days AS (
	SELECT COUNT(*) AS cloudy_days
	FROM v_weather_germany_2025 vwg 
	WHERE vwg.cloud >= 50  -- Bewölkung größer / gleich 50%
	AND NOT vwg.precip_mm > 0.0  -- und kein Niederschlag
), 
ct_rainy_days AS (
	SELECT COUNT(*) AS rainy_days
	FROM v_weather_germany_2025 vwg 
	WHERE vwg.precip_mm > 0.0
)
SELECT * FROM ct_sunny_days, ct_cloudy_days, ct_rainy_days;

/*
 * Finde
 * - die Anzahl sonniger Tage (cloud < 50) und kein Niederschlag
 * - die Anzahl bewölkter Tage (cloud >= 50) und kein Niederschlag
 * - die Anzahl Tage mit Niederschlag (precip_mm > 0)
 * 2025 in Deutschland (Berlin)
 * bezogen auf die Saison
 */
SELECT
COALESCE(vws.season, 'TOTAL') AS `season`,
COUNT(
CASE 
	WHEN cloud < 50 AND NOT precip_mm > 0 THEN 1 
END) AS sunny_days,
COUNT(
CASE 
	WHEN cloud >= 50 AND NOT precip_mm > 0 THEN 1 
END) AS cloudy_days,
COUNT(
CASE 
	WHEN precip_mm > 0 THEN 1 
END) AS rainy_days
FROM v_weather_germany_seasons vws
GROUP BY vws.season WITH ROLLUP
ORDER BY 
CASE
	WHEN vws.season LIKE 'Win%' THEN 0
	WHEN vws.season LIKE 'Frü%' THEN 1
	WHEN vws.season LIKE 'Som%' THEN 2
	ELSE 3
END;

/*
 * Finde
 * - die Anzahl sonniger Tage (cloud < 50) und kein Niederschlag
 * - die Anzahl bewölkter Tage (cloud >= 50) und kein Niederschlag
 * - die Anzahl Tage mit Niederschlag (precip_mm > 0)
 * 2025 IN Deutschland (Berlin)
 * bezogen auf die Monate Januar bis Dezember 2025
 */
CREATE OR REPLACE VIEW v_day_count_weather_conditions_germany_2025 AS
SELECT
COALESCE(vwg.`month`, 'TOTAL') AS `month`,
COUNT(
CASE 
	WHEN cloud < 50 AND NOT precip_mm > 0 THEN 1 
END) AS sunny_days,
COUNT(
CASE 
	WHEN cloud >= 50 AND NOT precip_mm > 0 THEN 1 
END) AS cloudy_days,
COUNT(
CASE 
	WHEN precip_mm > 0 THEN 1 
END) AS rainy_days
FROM v_weather_germany_2025 vwg 
GROUP BY vwg.`month` WITH rollup
ORDER BY 
CASE
	WHEN vwg.`month` LIKE 'Jan%' THEN 0
	WHEN vwg.`month` LIKE 'Feb%' THEN 1
	WHEN vwg.`month` LIKE 'Mär%' THEN 2
	WHEN vwg.`month` LIKE 'Apr%' THEN 3
	WHEN vwg.`month` LIKE 'Mai'  THEN 4
	WHEN vwg.`month` LIKE 'Jun%' THEN 5
	WHEN vwg.`month` LIKE 'Jul%' THEN 6
	WHEN vwg.`month` LIKE 'Aug%' THEN 7
	WHEN vwg.`month` LIKE 'Sep%' THEN 8
	WHEN vwg.`month` LIKE 'Okt%' THEN 9
	WHEN vwg.`month` LIKE 'Nov%' THEN 10
	ELSE 11
END;

SELECT * FROM v_day_count_weather_conditions_germany_2025;

CREATE OR REPLACE VIEW pbi_day_count_weather_conditions_germany_2025 AS
SELECT
vwg.`month`,
COUNT(
CASE 
	WHEN cloud < 50 AND NOT precip_mm > 0 THEN 1 
END) AS sunny_days,
COUNT(
CASE 
	WHEN cloud >= 50 AND NOT precip_mm > 0 THEN 1 
END) AS cloudy_days,
COUNT(
CASE 
	WHEN precip_mm > 0 THEN 1 
END) AS rainy_days
FROM v_weather_germany_2025 vwg 
GROUP BY vwg.`month`
ORDER BY 
CASE
	WHEN vwg.`month` LIKE 'Jan%' THEN 0
	WHEN vwg.`month` LIKE 'Feb%' THEN 1
	WHEN vwg.`month` LIKE 'Mär%' THEN 2
	WHEN vwg.`month` LIKE 'Apr%' THEN 3
	WHEN vwg.`month` LIKE 'Mai'  THEN 4
	WHEN vwg.`month` LIKE 'Jun%' THEN 5
	WHEN vwg.`month` LIKE 'Jul%' THEN 6
	WHEN vwg.`month` LIKE 'Aug%' THEN 7
	WHEN vwg.`month` LIKE 'Sep%' THEN 8
	WHEN vwg.`month` LIKE 'Okt%' THEN 9
	WHEN vwg.`month` LIKE 'Nov%' THEN 10
	ELSE 11
END;

/*
 * Zähle die Tage in Deutschland je nach Luftqualitätsindex
 * und gruppiere sie nach Monaten zur Einschätzung der Luftqualität in Berlin 2025
 * pro Monat
 */
CREATE OR REPLACE VIEW pbi_air_quality_germany AS
WITH tb_air_quality AS (
	SELECT vwg.location_name, 
	get_month(DATE(vwg.last_updated)) AS `month`,
	get_gb_defra_category(vwg.`air_quality_gb-defra-index`) AS air_quality_badness_category,
	COUNT(get_gb_defra_category(vwg.`air_quality_gb-defra-index`)) AS ct_air_quality_category,
	vwg.last_updated,
	EXTRACT(MONTH FROM vwg.last_updated) AS month_number
	FROM v_weather_germany_2025 vwg 
	WHERE EXTRACT(YEAR FROM vwg.last_updated) = 2025
	AND vwg.location_name LIKE '%berlin%'
	GROUP BY vwg.`month`, vwg.last_updated, vwg.`air_quality_gb-defra-index`, vwg.location_name
)
SELECT DISTINCT aq.location_name, 
aq.`month`,
aq.air_quality_badness_category AS air_quality_badness_category,
SUM(aq.ct_air_quality_category) AS ct_air_quality_category,
aq.month_number
FROM tb_air_quality aq
GROUP BY aq.air_quality_badness_category, aq.location_name, aq.`month`, aq.month_number
ORDER BY
CASE
	WHEN aq.`month` LIKE 'Jan%' THEN 0
	WHEN aq.`month` LIKE 'Feb%' THEN 1
	WHEN aq.`month` LIKE 'Mär%' THEN 2
	WHEN aq.`month` LIKE 'Apr%' THEN 3
	WHEN aq.`month` LIKE 'Mai'  THEN 4
	WHEN aq.`month` LIKE 'Jun%' THEN 5
	WHEN aq.`month` LIKE 'Jul%' THEN 6
	WHEN aq.`month` LIKE 'Aug%' THEN 7
	WHEN aq.`month` LIKE 'Sep%' THEN 8
	WHEN aq.`month` LIKE 'Okt%' THEN 9
	WHEN aq.`month` LIKE 'Nov%' THEN 10
	ELSE 11
END,
CASE
	WHEN aq.air_quality_badness_category = 'sehr schlecht' THEN 0
	WHEN aq.air_quality_badness_category = 'schlecht' THEN 1 
	WHEN aq.air_quality_badness_category = 'mittel' THEN 2 
	WHEN aq.air_quality_badness_category = 'gut' THEN 3
END;

SELECT * FROM pbi_air_quality_germany;

/*
 * Finde die 10 heißesten Orte in der europäischen Zeitzone im Jahr 2025
 */
CREATE OR REPLACE VIEW pbi_10_highest_temperatures_europe_2025 AS
SELECT vgt.country, 
ROUND(AVG(vgt.avg_temperature_celsius), 2) AS avg_temperature_celsius,
DENSE_RANK() OVER(ORDER BY AVG(vgt.avg_temperature_celsius) DESC) AS `ranking`
FROM v_grouped_timezones vgt
WHERE vgt.timezone LIKE '%europe%'
GROUP BY vgt.country
ORDER BY `ranking`, vgt.country
LIMIT 10;

SELECT * FROM pbi_10_highest_temperatures_europe_2025;

/*
 * Finde die 10 kältesten Orte in der europäischen Zeitzone im Jahr 2025
 */
CREATE OR REPLACE VIEW pbi_10_lowest_temperatures_europe_2025 AS
SELECT vgt.country, 
ROUND(AVG(vgt.avg_temperature_celsius), 2) AS avg_temperature_celsius,
DENSE_RANK() OVER(ORDER BY AVG(vgt.avg_temperature_celsius)) AS `ranking`
FROM v_grouped_timezones vgt 
WHERE vgt.timezone LIKE '%europe%'
GROUP BY vgt.country
ORDER BY `ranking`, vgt.country
LIMIT 10;

SELECT * FROM pbi_10_lowest_temperatures_europe_2025;


/* ---------------------------------------------------------
 * Analysen weltweit mit Fokus auf Wetterextreme - Aufgabe 2
 -------------------------------------------------------- */


/*
 * Finde die 10 Orte mit der höchsten Durchschnittstemperatur weltweit im Jahr 2025
 */
CREATE OR REPLACE VIEW pbi_10_highest_temperatures_worldwide AS
SELECT ROUND(AVG(cwf.temperature_celsius), 2) AS avg_max_temperatur_celsius,
cwf.location_name,
cwf.country
FROM pbi_countries_with_full_2025 cwf
WHERE EXTRACT(YEAR FROM cwf.last_updated) = 2025
GROUP BY cwf.location_name, cwf.country
ORDER BY avg_max_temperatur_celsius DESC
LIMIT 10;

SELECT * FROM pbi_10_highest_temperatures_worldwide;

/*
 * Finde die 10 Orte mit der niedrigsten Durchschnittstemperatur weltweit im Jahr 2025
 */
CREATE OR REPLACE VIEW pbi_10_lowest_temperatures_worldwide AS
SELECT ROUND(AVG(cwf.temperature_celsius), 2) AS avg_min_temperatur_celsius,
cwf.location_name,
cwf.country
FROM pbi_countries_with_full_2025 cwf
WHERE EXTRACT(YEAR FROM cwf.last_updated) = 2025
GROUP BY cwf.location_name, cwf.country
ORDER BY avg_max_temperatur_celsius
LIMIT 10;

SELECT * FROM pbi_10_lowest_temperatures_worldwide;

/* 
 * Finde die weltweit höchste Windgeschwindigkeit einer 2025 auftretenden Windböe
 */
CREATE OR REPLACE VIEW pbi_highest_wind_gust_worldwide AS
SELECT cwf.gust_kph AS max_gusts_kph,
cwf.wind_kph,
cwf.location_name,
cwf.country,
cwf.last_updated
FROM pbi_countries_with_full_2025 cwf
WHERE EXTRACT(YEAR FROM cwf.last_updated) = 2025
ORDER BY cwf.gust_kph DESC 
LIMIT 1;

SELECT * FROM pbi_highest_wind_gust_worldwide;

/*
 * Finde die 10 Orte mit der weltweit größten Luftverschmutzung mit CO 2025
 */
CREATE OR REPLACE VIEW pbi_10_countries_with_most_worst_air_quality_worldwide AS
SELECT ROUND(AVG(cwf.air_quality_carbon_monoxide), 2) AS avg_air_quality_carbon_monoxide,
cwf.location_name,
cwf.country
FROM pbi_countries_with_full_2025 cwf
WHERE EXTRACT(YEAR FROM cwf.last_updated) = 2025
GROUP BY cwf.location_name, cwf.country
ORDER BY avg_air_quality_carbon_monoxide DESC 
LIMIT 10;

SELECT * FROM pbi_10_countries_with_most_worst_air_quality_worldwide;

/*
 * Finde die 10 Orte mit der weltweit niedrigsten Luftverschmutzung mit CO 2025
 */
CREATE OR REPLACE VIEW pbi_10_contries_with_best_air_quality_worldwide AS
SELECT ROUND(AVG(cwf.air_quality_carbon_monoxide), 2) AS avg_air_quality_carbon_monoxide,
cwf.location_name,
cwf.country
FROM pbi_countries_with_full_2025 cwf
WHERE EXTRACT(YEAR FROM cwf.last_updated) = 2025
GROUP BY cwf.location_name, cwf.country
ORDER BY avg_air_quality_carbon_monoxide
LIMIT 10;

SELECT * FROM pbi_10_contries_with_best_air_quality_worldwide;

/*
 * Erkennen von Zusammenhängen zwischen verschiedenen Parametern mittels Korrelationen
 * 
 * Verwendung von STDDEV_POP sorgt dafür, dass NULL-Werte automatisch ignoriert werden
 * (ähnlich wie COALESCE(0))
 */


/*
 * Gibt es einen Zusammenhang zwischen der Menge an Feinstaubpartikeln < 2.5 Mikrometern
 * und der Menge an Feinstaubpartikeln < 10 Mikrometern und wie stark ist 
 * dieser Zusammenhang?
 */
SELECT 
ROUND((AVG(cwf.`air_quality_pm2.5` * cwf.air_quality_pm10) - AVG(cwf.`air_quality_pm2.5`) * AVG(cwf.air_quality_pm10)) / 
(STDDEV_POP(cwf.`air_quality_pm2.5`) * STDDEV_POP(cwf.air_quality_pm10)), 2) AS c_air_quality_pm2_5_VS_air_quality_pm10
FROM pbi_countries_with_full_2025 cwf INTO @corr_pm2_5_VS_pm10;

SELECT @corr_pm2_5_VS_pm10 AS `Correlation value between micro dust < 2.5 micrometer and micro dust < 10 micrometer`,
get_correlation_category(@corr_pm2_5_VS_pm10) AS `Correlation category`;

/*
 * Aufgrund der hohen Korrelation zwischen der Menge an Feinstaubpartikeln untereinander
 * betrachte ich im folgenden die Korrelationen zu Feinstaub nur für Feinstaubpartikel < 10 Mikrometer,
 * da diese wahrscheinlich z.T. oder ganz die Menge der Feinstaubpartikel < 2.5 enthalten
 * (vermutlich kommt daher der hohe Korrelationswert)
 */

/*
 * Gibt es einen Zusammenhang zwischen der Menge an Feinstaubpartikeln < 10 Mikrometern
 * und der Temperatur?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT 
ROUND((AVG(cwf.air_quality_pm10 * cwf.temperature_celsius) - AVG(cwf.air_quality_pm10) * AVG(cwf.temperature_celsius)) /
(STDDEV_POP(cwf.air_quality_pm10) * STDDEV_POP(cwf.temperature_celsius)), 2) AS c_air_quality_pm10_VS_temperature_celsius
FROM pbi_countries_with_full_2025 cwf INTO @corr_pm10_VS_temperature_celsius;

SELECT @corr_pm10_VS_temperature_celsius AS `Correlation value between micro dust < 10 micrometer and temperature in °C`,
get_correlation_category(@corr_pm10_VS_temperature_celsius) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen der Menge an Feinstaubpartikeln < 10 Mikrometern
 * und der Niederschlagsmenge?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT 
ROUND((AVG(cwf.air_quality_pm10 * cwf.precip_mm) - AVG(cwf.air_quality_pm10) * AVG(cwf.precip_mm)) /
(STDDEV_POP(cwf.air_quality_pm10) * STDDEV_POP(cwf.precip_mm)), 2) AS c_air_quality_pm10_VS_precip_mm
FROM pbi_countries_with_full_2025 cwf INTO @corr_pm10_VS_precip_mm;

SELECT @corr_pm10_VS_precip_mm AS `Correlation value between micro dust < 10 micrometer and amount of rain`,
get_correlation_category(@corr_pm10_VS_precip_mm) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen der Menge an Feinstaubpartikeln < 10 Mikrometern
 * und der Bewölkung?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT 
ROUND((AVG(cwf.air_quality_pm10 * cwf.cloud) - AVG(cwf.air_quality_pm10) * AVG(cwf.cloud)) /
(STDDEV_POP(cwf.air_quality_pm10) * STDDEV_POP(cwf.cloud)), 2) AS c_air_quality_pm10_VS_cloud
FROM pbi_countries_with_full_2025 cwf INTO @corr_pm10_VS_cloud;

SELECT @corr_pm10_VS_cloud AS `Correlation value between micro dust < 10 micrometer and amount of clouds`,
get_correlation_category(@corr_pm10_VS_cloud) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen der Menge an Feinstaubpartikeln < 10 Mikrometern
 * und der Sichtweite in km?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT 
ROUND((AVG(cwf.air_quality_pm10 * cwf.visibility_km) - AVG(cwf.air_quality_pm10) * AVG(cwf.visibility_km)) /
(STDDEV_POP(cwf.air_quality_pm10) * STDDEV_POP(cwf.visibility_km)), 2) AS c_air_quality_pm10_VS_visibility_km
FROM pbi_countries_with_full_2025 cwf INTO @corr_pm10_VS_visibility_km;

SELECT @corr_pm10_VS_visibility_km AS `Correlation value between micro dust < 10 micrometer and the visibility in km`,
get_correlation_category(@corr_pm10_VS_visibility_km) AS `Correlation category`;

/* 
 * Analyse weiterer möglicherweise interessanter Zusammenhänge als Zusatz
 */

/*
 * Gibt es einen Zusammenhang zwischen der Sichtweite in km und der Luftfeuchtigkeit?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT 
ROUND((AVG(cwf.visibility_km * cwf.humidity) - AVG(cwf.visibility_km) * AVG(cwf.humidity)) /
(STDDEV_POP(cwf.visibility_km) * STDDEV_POP(cwf.humidity)), 2) AS c_visibility_km_VS_humidity
FROM pbi_countries_with_full_2025 cwf INTO @corr_visibility_VS_humidity;

SELECT @corr_visibility_VS_humidity AS `Correlation value between visibility in km and humidity in percent`,
get_correlation_category(@corr_visibility_VS_humidity) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen der Temperatur in °C und der Luffeuchtigkeit?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT 
ROUND((AVG(cwf.temperature_celsius * cwf.humidity) - AVG(cwf.temperature_celsius) * AVG(cwf.humidity)) /
(STDDEV_POP(cwf.temperature_celsius) * STDDEV_POP(cwf.humidity)), 2) AS c_temperature_celsius_VS_humidity 
FROM pbi_countries_with_full_2025 cwf INTO @corr_temperature_VS_humidity;

SELECT @corr_temperature_VS_humidity AS `Correlation value between temperature in celsius and humidity in percent`,
get_correlation_category(@corr_temperature_VS_humidity) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen der gefühlten Temperatur in °C und der Luftfeuchtigkeit?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT 
ROUND((AVG(cwf.feels_like_celsius * cwf.humidity) - AVG(cwf.feels_like_celsius) * AVG(cwf.humidity)) /
(STDDEV_POP(cwf.feels_like_celsius) * STDDEV_POP(cwf.humidity)), 2) AS c_feels_like_celsius_VS_humidity 
FROM pbi_countries_with_full_2025 cwf INTO @corr_feeled_temp_VS_humidity;

SELECT @corr_feeled_temp_VS_humidity AS `Correlation value between feeled temperature in celsius and humidity in percent`,
get_correlation_category(@corr_feeled_temp_VS_humidity) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen dem Ozon Wert und dem UV Index?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT 
ROUND((AVG(cwf.air_quality_Ozone * cwf.uv_index) - AVG(cwf.air_quality_Ozone) * AVG(cwf.uv_index)) /
(STDDEV_POP(cwf.air_quality_Ozone) * STDDEV_POP(cwf.uv_index)), 2) AS c_ozone_VS_uv_index
FROM pbi_countries_with_full_2025 cwf INTO @corr_ozone_VS_uv_index;

SELECT @corr_ozone_VS_uv_index AS `Correlation value between ozone and uv index`,
get_correlation_category(@corr_ozone_VS_uv_index) AS `Correlation category`;

/*
 * Finde den Ort und den Zeitpunkt mit dem höchsten Wert des UV Index weltweit 2025
 */
CREATE OR REPLACE VIEW pbi_highest_uv_index_worldwide_2025 AS
SELECT cwf.uv_index AS max_uv_index,
cwf.location_name,
cwf.country
FROM pbi_countries_with_full_2025 cwf
WHERE EXTRACT(YEAR FROM cwf.last_updated) = 2025
ORDER BY cwf.uv_index DESC
LIMIT 1;

SELECT * FROM pbi_highest_uv_index_worldwide_2025;

/*
 * Finde alle Orte, die 2025 einen maximalen UV Index von >= 11 aufwiesen.
 * Ab diesem UV Index bekommt man unabhängig von Sonnenschutzmitteln innerhalb
 * von wenigen Minuten einen Sonnenbrand. Die besten Schutzmaßnahmen sind an
 * diesen Orten die vollständige Bedeckung mit Kleidungsstücken oder das Aufhalten
 * ausschließlich in geschlossenen Räumen.
 */
SELECT cwf.uv_index AS max_uv_index,
cwf.location_name,
cwf.country
FROM pbi_countries_with_full_2025 cwf
WHERE EXTRACT(YEAR FROM cwf.last_updated) = 2025
AND cwf.uv_index >= 11
ORDER BY cwf.uv_index DESC;

WITH wind_counts AS (
    SELECT 
        cwf.wind_direction,
        COUNT(*) AS count_per_type
    FROM pbi_countries_with_full_2025 cwf
    WHERE location_name = 'Berlin'
    AND EXTRACT(YEAR FROM cwf.last_updated) = 2025
    AND cwf.wind_direction IS NOT NULL
    GROUP BY cwf.wind_direction
),
total_count AS (
    SELECT SUM(count_per_type) AS total_rows
    FROM wind_counts
)
SELECT 
    wc.wind_direction,
    wc.count_per_type,
    ROUND((wc.count_per_type * 100.0 / tc.total_rows), 2) AS percentage
FROM wind_counts wc
CROSS JOIN total_count tc
ORDER BY wc.count_per_type DESC;

/*
 * Finde das durchschnittliche Sonnenbrandrisiko in Berlin 2025 in Prozent heraus
 */
CREATE OR REPLACE VIEW pbi_sunburn_risk_level_berlin_2025 AS
WITH tb_risk_level AS (
	SELECT ROUND(cwf.uv_index) AS uv_index_rounded, 
	COUNT(get_uv_risk(ROUND(cwf.uv_index))) AS ct_uv_risk_level,
	get_uv_risk(ROUND(cwf.uv_index)) AS uv_risk_level
	FROM pbi_countries_with_full_2025 cwf 
	WHERE cwf.location_name LIKE '%berlin%'
	AND EXTRACT(YEAR FROM cwf.last_updated) = 2025
	GROUP BY uv_index_rounded, cwf.uv_index, uv_risk_level
	ORDER BY 
	CASE
		WHEN ROUND(cwf.uv_index) >= 11 THEN 0
		WHEN ROUND(cwf.uv_index) BETWEEN 8 AND 10 THEN 1
		WHEN ROUND(cwf.uv_index) BETWEEN 6 AND 7 THEN 2
		WHEN ROUND(cwf.uv_index) BETWEEN 3 AND 5 THEN 3
		WHEN ROUND(cwf.uv_index) BETWEEN 1 AND 2 THEN 4
		ELSE 5
	END
), tb_uv_risk_level_count AS (
SELECT rl.uv_index_rounded AS uv_index_rounded,
	SUM(rl.ct_uv_risk_level) AS ct_uv_risk_level,
	rl.uv_risk_level AS uv_risk_level
	FROM tb_risk_level rl
	GROUP BY rl.uv_index_rounded, rl.uv_risk_level
)
SELECT SUM(urlc.ct_uv_risk_level) AS sum_uv_risk_level,
urlc.uv_risk_level, 
ROUND(SUM(urlc.ct_uv_risk_level) * 100 / 365, 2) AS percentual_risk_level
FROM tb_uv_risk_level_count urlc
GROUP BY urlc.uv_risk_level;

SELECT * FROM pbi_sunburn_risk_level_berlin_2025;