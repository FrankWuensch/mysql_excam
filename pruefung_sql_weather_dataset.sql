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
SELECT
	COUNT(*) AS ct_lines
FROM
	GlobalWeatherRepository gwr
WHERE
	EXTRACT(YEAR FROM gwr.last_updated) = 2025;
DELIMITER //

/*
 * Funktion zur Kategorisierung eines Korrelationswertes
 */
CREATE FUNCTION get_correlation_category(value DECIMAL(4, 2))
RETURNS VARCHAR(30)
DETERMINISTIC
BEGIN 
    IF ABS(value) >= 0.5 THEN
-- ABS verwendet den Betrag der Zahl, also ohne Beachtung des Vorzeichens
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
	SET
lc_time_names = 'de_DE';
-- Rückgabe der deutschen Namen für Monate
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
SELECT
	get_correlation_category(0.5) AS correlation_category;
-- Erwartet: 'Starke Korrelation'
SELECT
	get_correlation_category(0.3) AS correlation_category;
-- Erwartet: 'Mittlere Korrelation'
SELECT
	get_correlation_category(0.1) AS correlation_category;
-- Erwartet: 'Geringe Korrelation'
SELECT
	get_correlation_category(-0.1) AS correlation_category;
-- Erwartet: 'Geringe Korrelation'
SELECT
	get_correlation_category(-0.3) AS correlation_category;
-- Erwartet: 'Mittlere Korrelation'
SELECT
	get_correlation_category(-0.5) AS correlation_category;
-- Erwartet: 'Starke Korrelation'

SELECT
	get_uv_risk(7) AS uv_risk_level;
-- Erwartet: 'Hohes Risiko'

SELECT
	get_season('2024-12-21') AS season;
-- Erwartet: 'Winter'
SELECT
	get_season('2024-12-20') AS season;
-- Erwartet: NULL

SELECT
	get_month('2025-01-04') AS `month`;
-- Erwartet: 'Januar'
SELECT
	get_month('2025-03-20') AS `month`;
-- Erwartet: 'März'
SELECT
	get_month('2024-12-21') AS `month`;
-- Erwartet: 'Dezember'

SELECT
	get_gb_defra_category(5) AS category;
-- Erwartet: 'schlecht'

/*
 * Mit den folgenden Abfragen verschaffe ich mir einen grundsätzlichen Überblick über 
 * die vorhandenen Daten in der Datenbanktabelle
 */
SELECT
	gwr.country,
	gwr.timezone
FROM
	GlobalWeatherRepository gwr
GROUP BY
	gwr.country,
	gwr.timezone
ORDER BY
	gwr.timezone,
	gwr.country;

SELECT
	DISTINCT gwr.country,
	COUNT(gwr.country) AS ct_days
FROM
	GlobalWeatherRepository gwr
GROUP BY
	gwr.country;

SELECT
	MIN(gwr.temperature_celsius) AS abs_min_temp,
	gwr.location_name,
	gwr.country,
	COUNT(gwr.country) AS day_count
FROM
	GlobalWeatherRepository gwr
WHERE
	EXTRACT(YEAR FROM gwr.last_updated) = 2025
GROUP BY
	gwr.location_name,
	gwr.country
HAVING
	day_count = 365
ORDER BY
	MIN(gwr.temperature_celsius);

SELECT
	MAX(gwr.temperature_celsius) AS abs_max_temp,
	gwr.location_name,
	gwr.country,
	COUNT(gwr.country) AS day_count
FROM
	GlobalWeatherRepository gwr
WHERE
	EXTRACT(YEAR FROM gwr.last_updated) = 2025
GROUP BY
	gwr.location_name,
	gwr.country
HAVING
	day_count = 365
ORDER BY
	MAX(gwr.temperature_celsius) DESC;

/* 
 * Liste alle Länder auf, die vollständige Daten für das Jahr 2025 enthalten
 */
CREATE OR REPLACE
VIEW v_countries_with_full_2025 AS
SELECT
	gwr.location_name,
	gwr.country,
	gwr.timezone,
	COUNT(gwr.location_name) AS ct_days
FROM
	GlobalWeatherRepository gwr
WHERE
	EXTRACT(YEAR FROM gwr.last_updated) = 2025
GROUP BY
	gwr.location_name,
	gwr.country,
	gwr.timezone
HAVING
	COUNT(gwr.location_name) = 365
ORDER BY
	gwr.location_name;

SELECT
	*
FROM
	v_countries_with_full_2025 vcwf;

CREATE OR REPLACE
VIEW pbi_countries_with_full_2025 AS
WITH
tb_countries_2025 AS (
SELECT
	gwr.country, 
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
FROM
	GlobalWeatherRepository gwr
WHERE
	EXTRACT(YEAR FROM gwr.last_updated) = 2025
ORDER BY
	gwr.country,
	gwr.last_updated
)
SELECT
	*
FROM
	tb_countries_2025
WHERE
	location_name IN (
	SELECT
		DISTINCT vcwf.location_name
	FROM
		v_countries_with_full_2025 vcwf
);

SELECT
	COUNT(*)
FROM
	pbi_countries_with_full_2025;

SELECT
	DISTINCT country,
	timezone
FROM
	pbi_countries_with_full_2025;

/*
 * Zeige alle Länder innerhalb der europäischen Zeitzone, die vollständige Daten
 * für das Jahr 2025 enthalten
 */
SELECT
	DISTINCT pcwf.country,
	pcwf.timezone,
	COUNT(pcwf.country) AS ct_days
FROM
	pbi_countries_with_full_2025 pcwf
WHERE
	EXTRACT(YEAR FROM pcwf.last_updated) = 2025
	AND pcwf.timezone LIKE '%europe%'
GROUP BY
	pcwf.country,
	pcwf.timezone
HAVING
	COUNT(pcwf.country) = 365
ORDER BY
	pcwf.country;

SELECT
	COUNT(*) AS ct_days
FROM
	pbi_countries_with_full_2025 pcwf
WHERE
	EXTRACT(YEAR FROM pcwf.last_updated) = 2025
	AND pcwf.location_name LIKE '%berlin%';

/*
 * Durchschnittliche Wetterbedingungen hinsichtlich Zeitzonen und Länder 2025
 * Sortiert wird nach Ländern in der europäischen Zeitzone;
 * innerhalb der Zeitzonen wird alphabetisch aufsteigend nach Land sortiert
 * 
 * Die Abfrage wird als VIEW v_grouped_timezones abgespeichert, um die Daten nicht
 * bei jeder Abfrage neu filtern zu müssen.
 */
CREATE OR REPLACE
VIEW pbi_european_timezone_2025 AS
SELECT
	*
FROM
	pbi_countries_with_full_2025 pcwf
WHERE
	pcwf.timezone LIKE '%europe%';

SELECT
	*
FROM
	pbi_european_timezone_2025;

/* ---------------------------------------------------
 * Analysen deutschlandweit und europaweit - Aufgabe 1
 -------------------------------------------------- */

/* 
 * Erstellen einer VIEW, die alle Wetterdaten für das Jahr 2025 in Deutschland speichert
 * Verwendung für Analysen, die sich auf die Monate oder das gesamte Jahr beziehen
 */
CREATE OR REPLACE
VIEW v_weather_germany_2025 AS (
SELECT
	pcwf.location_name,
	pcwf.country,
	pcwf.temperature_celsius,
	pcwf.feels_like_celsius,
	pcwf.wind_kph,
	pcwf.gust_kph,
	pcwf.wind_direction,
	pcwf.pressure_mb,
	pcwf.precip_mm,
	pcwf.humidity,
	pcwf.visibility_km,
	pcwf.air_quality_carbon_monoxide,
	pcwf.air_quality_ozone,
	pcwf.air_quality_nitrogen_dioxide,
	pcwf.air_quality_sulphur_dioxide,
	pcwf.`air_quality_us-epa-index`,
	pcwf.`air_quality_gb-defra-index`,
	pcwf.cloud,
	pcwf.last_updated,
	get_month(DATE(pcwf.last_updated)) AS `month`,
	EXTRACT(MONTH FROM pcwf.last_updated) AS month_number
FROM
	pbi_countries_with_full_2025 pcwf
WHERE
	EXTRACT(YEAR FROM pcwf.last_updated) = 2025
	AND pcwf.location_name LIKE '%berlin%'
ORDER BY
	pcwf.last_updated
);

CREATE OR REPLACE
VIEW pbi_weather_germany_2025 AS (
SELECT
	*
FROM
	v_weather_germany_2025
);

SELECT
	*
FROM
	pbi_weather_germany_2025;

/*
 * Berechne die Regensumme für Deutschland 2025 und erstelle eine View für PowerBI
 */
CREATE OR REPLACE
VIEW pbi_sum_rain_germany_2025 AS
SELECT
	SUM(wg.precip_mm) AS sum_precip_mm
FROM
	pbi_weather_germany_2025 wg;

SELECT
	*
FROM
	pbi_sum_rain_germany_2025;

/*
 * Berechne die durchschnittliche gefühlte Temperatur für Deutschland 2025
 * und erstelle eine View für Power BI
 */
CREATE OR REPLACE
VIEW pbi_avg_feeled_temperature_germany_2025 AS
SELECT
	ROUND(AVG(wg.feels_like_celsius), 2) AS avg_feeled_temp
FROM
	pbi_weather_germany_2025 wg;

SELECT
	*
FROM
	pbi_avg_feeled_temperature_germany_2025;

/*
 * Berechne die Durchschnittstemperatur für Deutschland 2025 und erstelle eine View für Power BI
 */
CREATE OR REPLACE
VIEW pbi_avg_temperature_germany_2025 AS
SELECT
	ROUND(AVG(wg.temperature_celsius), 2) AS avg_temp_germany
FROM
	pbi_weather_germany_2025 wg;

SELECT
	*
FROM
	pbi_avg_temperature_germany_2025;

/*
 * Berechne die minimale Temperatur für Deutschland 2025 und erstelle eine View für PowerBI
 */
CREATE OR REPLACE
VIEW pbi_min_temperature_germany_2025 AS
SELECT
	MIN(wg.temperature_celsius) AS min_temp_germany
FROM
	pbi_weather_germany_2025 wg;

SELECT
	*
FROM
	pbi_min_temperature_germany_2025;

/*
 * Berechne die maximale Temperatur für Deutschland 2025 und erstelle eine View für PowerBI
 */
CREATE OR REPLACE
VIEW pbi_max_temperature_germany_2025 AS
SELECT
	MAX(wg.temperature_celsius) AS max_temp_germany
FROM
	pbi_weather_germany_2025 wg;

SELECT
	*
FROM
	pbi_max_temperature_germany_2025;

/* 
 * Erstellen einer VIEW, die alle Wetterdaten im Zeitraum 21.12.2024 bis 20.12.2025 in Deutschland speichert
 * Verwendung ausschließlich für Analysen, die auf die Saison bezogen sind
 */
CREATE OR REPLACE
VIEW v_weather_germany_seasons AS (
SELECT
	gwr.location_name,
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
FROM
	GlobalWeatherRepository gwr
WHERE
	DATE(gwr.last_updated) BETWEEN DATE('2024-12-21') AND DATE('2025-12-20')
		AND gwr.location_name LIKE '%berlin%'
	ORDER BY
		gwr.last_updated
);

CREATE OR REPLACE
VIEW pbi_weather_germany_with_seasons AS
SELECT
	*
FROM
	v_weather_germany_seasons;

SELECT
	*
FROM
	pbi_weather_germany_with_seasons;

/*
 * Berechne die durchschnittliche Temperatur in Deutschland bezogen auf die
 * saisonale Betrachtung und erstelle eine View für Power BI
 */
CREATE OR REPLACE
VIEW pbi_avg_temperature_germany_seasons AS
SELECT
	ROUND(AVG(wgs.temperature_celsius), 2) AS avg_temp_seasons_germany
FROM
	pbi_weather_germany_with_seasons wgs;

SELECT
	*
FROM
	pbi_avg_temperature_germany_seasons;

/*
 * Berechne die minimale Temperatur in Deutschland bezogen auf die
 * saisonale Betrachtung und erstelle eine View für Power BI
 */
CREATE OR REPLACE
VIEW pbi_min_temperature_germany_seasons AS
SELECT
	MIN(wgs.temperature_celsius) AS min_temp_seasons_germany
FROM
	pbi_weather_germany_with_seasons wgs;

SELECT
	*
FROM
	pbi_min_temperature_germany_seasons;

/*
 * Berechne die maximale Temperatur in Deutschland bezogen auf die
 * saisonale Betrachtung und erstelle eine View für Power BI
 */
CREATE OR REPLACE
VIEW pbi_max_temperature_germany_seasons AS
SELECT
	MAX(wgs.temperature_celsius) AS max_temp_seasons_germany
FROM
	pbi_weather_germany_with_seasons wgs;

SELECT
	*
FROM
	pbi_max_temperature_germany_seasons;

/*
 * Finde
 * - die Anzahl sonniger Tage (cloud < 50) und kein Niederschlag
 * - die Anzahl bewölkter Tage (cloud >= 50) und kein Niederschlag
 * - die Anzahl Tage mit Niederschlag (precip_mm > 0)
 * 2025 IN Deutschland (Berlin)
 */
WITH 
ct_sunny_days AS (
SELECT
	COUNT(*) AS sunny_days
FROM
	v_weather_germany_2025 vwg
WHERE
	vwg.cloud < 50
	-- Bewölkung kleiner 50%
	AND NOT vwg.precip_mm > 0.0
	-- und kein Niederschlag
), 
ct_cloudy_days AS (
SELECT
	COUNT(*) AS cloudy_days
FROM
	v_weather_germany_2025 vwg
WHERE
	vwg.cloud >= 50
	-- Bewölkung größer / gleich 50%
	AND NOT vwg.precip_mm > 0.0
	-- und kein Niederschlag
), 
ct_rainy_days AS (
SELECT
	COUNT(*) AS rainy_days
FROM
	v_weather_germany_2025 vwg
WHERE
	vwg.precip_mm > 0.0
)
SELECT
	*
FROM
	ct_sunny_days,
	ct_cloudy_days,
	ct_rainy_days;

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
FROM
	v_weather_germany_seasons vws
GROUP BY
	vws.season WITH ROLLUP
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
CREATE OR REPLACE
VIEW v_day_count_weather_conditions_germany_2025 AS
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
FROM
	v_weather_germany_2025 vwg
GROUP BY
	vwg.`month` WITH rollup
ORDER BY
	CASE
		WHEN vwg.`month` LIKE 'Jan%' THEN 0
		WHEN vwg.`month` LIKE 'Feb%' THEN 1
		WHEN vwg.`month` LIKE 'Mär%' THEN 2
		WHEN vwg.`month` LIKE 'Apr%' THEN 3
		WHEN vwg.`month` LIKE 'Mai' THEN 4
		WHEN vwg.`month` LIKE 'Jun%' THEN 5
		WHEN vwg.`month` LIKE 'Jul%' THEN 6
		WHEN vwg.`month` LIKE 'Aug%' THEN 7
		WHEN vwg.`month` LIKE 'Sep%' THEN 8
		WHEN vwg.`month` LIKE 'Okt%' THEN 9
		WHEN vwg.`month` LIKE 'Nov%' THEN 10
		ELSE 11
	END;

SELECT
	*
FROM
	v_day_count_weather_conditions_germany_2025;

CREATE OR REPLACE
VIEW pbi_day_count_weather_conditions_germany_2025 AS
SELECT
	vwg.`month`,
	LEFT(vwg.`month`, 3) AS month_short,
	CASE
		WHEN vwg.`month` LIKE 'Jan%' THEN 1
		WHEN vwg.`month` LIKE 'Feb%' THEN 2
		WHEN vwg.`month` LIKE 'Mär%' THEN 3
		WHEN vwg.`month` LIKE 'Apr%' THEN 4
		WHEN vwg.`month` LIKE 'Mai' THEN 5
		WHEN vwg.`month` LIKE 'Jun%' THEN 6
		WHEN vwg.`month` LIKE 'Jul%' THEN 7
		WHEN vwg.`month` LIKE 'Aug%' THEN 8
		WHEN vwg.`month` LIKE 'Sep%' THEN 9
		WHEN vwg.`month` LIKE 'Okt%' THEN 10
		WHEN vwg.`month` LIKE 'Nov%' THEN 11
		ELSE 12
	END AS month_number,
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
FROM
	v_weather_germany_2025 vwg
GROUP BY
	vwg.`month`
ORDER BY
	CASE
		WHEN vwg.`month` LIKE 'Jan%' THEN 0
		WHEN vwg.`month` LIKE 'Feb%' THEN 1
		WHEN vwg.`month` LIKE 'Mär%' THEN 2
		WHEN vwg.`month` LIKE 'Apr%' THEN 3
		WHEN vwg.`month` LIKE 'Mai' THEN 4
		WHEN vwg.`month` LIKE 'Jun%' THEN 5
		WHEN vwg.`month` LIKE 'Jul%' THEN 6
		WHEN vwg.`month` LIKE 'Aug%' THEN 7
		WHEN vwg.`month` LIKE 'Sep%' THEN 8
		WHEN vwg.`month` LIKE 'Okt%' THEN 9
		WHEN vwg.`month` LIKE 'Nov%' THEN 10
		ELSE 11
	END;

SELECT
	*
FROM
	pbi_day_count_weather_conditions_germany_2025;

/*
 * Finde
 * - die Anzahl sonniger Tage (cloud < 50) und kein Niederschlag
 * - die Anzahl bewölkter Tage (cloud >= 50) und kein Niederschlag
 * - die Anzahl Tage mit Niederschlag (precip_mm > 0)
 * 2025 IN Deutschland (Berlin)
 * bezogen auf die Jahreszeiten
 */
CREATE OR REPLACE
VIEW pbi_day_count_weather_conditions_germany_seasons AS
SELECT
	vws.`season`,
	CASE
		WHEN vws.season LIKE 'Win%' THEN 1
		WHEN vws.season LIKE 'Frü%' THEN 2
		WHEN vws.season LIKE 'Som%' THEN 3
		ELSE 4
	END AS season_number,
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
FROM
	v_weather_germany_seasons vws
GROUP BY
	vws.`season`
ORDER BY
	CASE
		WHEN vws.season LIKE 'Win%' THEN 0
		WHEN vws.season LIKE 'Frü%' THEN 1
		WHEN vws.season LIKE 'Som%' THEN 2
		ELSE 3
	END;

SELECT
	*
FROM
	pbi_day_count_weather_conditions_germany_seasons;

/*
 * Zähle die Tage in Deutschland je nach Luftqualitätsindex
 * und gruppiere sie nach Monaten zur Einschätzung der Luftqualität in Berlin 2025
 * pro Monat
 */
CREATE OR REPLACE
VIEW pbi_air_quality_germany AS
WITH tb_air_quality AS (
SELECT
	vwg.location_name, 
	get_month(DATE(vwg.last_updated)) AS `month`,
	get_gb_defra_category(vwg.`air_quality_gb-defra-index`) AS air_quality_badness_category,
	COUNT(get_gb_defra_category(vwg.`air_quality_gb-defra-index`)) AS ct_air_quality_category,
	vwg.last_updated,
	EXTRACT(MONTH FROM vwg.last_updated) AS month_number
FROM
	v_weather_germany_2025 vwg
WHERE
	EXTRACT(YEAR FROM vwg.last_updated) = 2025
	AND vwg.location_name LIKE '%berlin%'
GROUP BY
	vwg.`month`,
	vwg.last_updated,
	vwg.`air_quality_gb-defra-index`,
	vwg.location_name
)
SELECT
	DISTINCT aq.location_name,
	aq.`month`,
	aq.air_quality_badness_category AS air_quality_badness_category,
	SUM(aq.ct_air_quality_category) AS ct_air_quality_category,
	aq.month_number
FROM
	tb_air_quality aq
GROUP BY
	aq.air_quality_badness_category,
	aq.location_name,
	aq.`month`,
	aq.month_number
ORDER BY
	CASE
		WHEN aq.`month` LIKE 'Jan%' THEN 0
		WHEN aq.`month` LIKE 'Feb%' THEN 1
		WHEN aq.`month` LIKE 'Mär%' THEN 2
		WHEN aq.`month` LIKE 'Apr%' THEN 3
		WHEN aq.`month` LIKE 'Mai' THEN 4
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

SELECT
	*
FROM
	pbi_air_quality_germany;

/*
 * Berechne die Niederschlagssume monatlich inkl. der durchschnittlichen
 * Luftfeuchtigkeit für Deutschland (Berlin) 2025
 */
CREATE OR REPLACE
VIEW pbi_avg_rain_germany_2025 AS
WITH tb_avg_rain_monthly AS (
SELECT
	get_month(DATE(pwg.last_updated)) AS `month`,
	EXTRACT(MONTH FROM pwg.last_updated) AS month_number,
	SUM(pwg.precip_mm) AS sum_rain,
	ROUND(AVG(pwg.humidity), 2) AS humidity,
	DENSE_RANK() OVER (
ORDER BY
	SUM(pwg.precip_mm) DESC) AS ranking
FROM
	pbi_weather_germany_2025 pwg
GROUP BY
	get_month(DATE(pwg.last_updated)),
	EXTRACT(MONTH FROM pwg.last_updated)
)
SELECT
	DISTINCT *
FROM
	tb_avg_rain_monthly srm
ORDER BY
	srm.ranking;

SELECT
	*
FROM
	pbi_avg_rain_germany_2025;

/*
 * Analysen bezogen auf die europäische Zeitzone
 */

/*
 * Berechne die durchschnittliche Temperatur 2025 und erstelle eine View für PowerBI
 */
CREATE OR REPLACE
VIEW pbi_avg_temperature_european_timezone_2025 AS
SELECT
	ROUND(AVG(pet.temperature_celsius), 2) AS avg_temp_european_timezone_2025
FROM
	pbi_european_timezone_2025 pet;

SELECT
	*
FROM
	pbi_avg_temperature_european_timezone_2025;

/*
 * Berechne die minimale Temperatur 2025 und erstelle eine View für PowerBI
 */
CREATE OR REPLACE
VIEW pbi_min_temperature_european_timezone_2025 AS
SELECT
	MIN(pet.temperature_celsius) AS min_temp_european_timezone_2025,
	pet.location_name,
	pet.country
FROM
	pbi_european_timezone_2025 pet
GROUP BY
	pet.location_name,
	pet.country
ORDER BY
	min_temp_european_timezone_2025
LIMIT 1;

SELECT
	*
FROM
	pbi_min_temperature_european_timezone_2025;

/*
 * Berechne die maximale Temperatur 2025 und erstelle eine View für PowerBI
 */
CREATE OR REPLACE
VIEW pbi_max_temperature_european_timezone_2025 AS
SELECT
	MAX(pet.temperature_celsius) AS max_temp_european_timezone_2025,
	pet.location_name,
	pet.country
FROM
	pbi_european_timezone_2025 pet
GROUP BY
	pet.location_name,
	pet.country
ORDER BY
	max_temp_european_timezone_2025 DESC
LIMIT 1;

SELECT
	*
FROM
	pbi_max_temperature_european_timezone_2025;

/*
 * Finde die 10 heißesten Länder in der europäischen Zeitzone im Jahr 2025
 */
CREATE OR REPLACE
VIEW pbi_avg_10_highest_temperatures_europe_2025 AS
SELECT
	pcwf.location_name,
	pcwf.country,
	ROUND(AVG(pcwf.temperature_celsius), 2) AS avg_temperature_celsius,
	DENSE_RANK() OVER(ORDER BY AVG(pcwf.temperature_celsius) DESC) AS `ranking`
FROM
	pbi_countries_with_full_2025 pcwf
WHERE
	pcwf.timezone LIKE '%europe%'
GROUP BY
	pcwf.location_name,
	pcwf.country,
	pcwf.timezone
ORDER BY
	`ranking`,
	pcwf.country
LIMIT 10;

SELECT
	*
FROM
	pbi_avg_10_highest_temperatures_europe_2025;

/*
 * Finde die 10 kältesten Länder in der europäischen Zeitzone im Jahr 2025
 */
CREATE OR REPLACE
VIEW pbi_avg_10_lowest_temperatures_europe_2025 AS
SELECT
	pcwf.location_name,
	pcwf.country,
	ROUND(AVG(pcwf.temperature_celsius), 2) AS avg_temperature_celsius,
	DENSE_RANK() OVER(ORDER BY AVG(pcwf.temperature_celsius)) AS `ranking`
FROM
	pbi_countries_with_full_2025 pcwf
WHERE
	pcwf.timezone LIKE '%europe%'
GROUP BY
	pcwf.location_name,
	pcwf.country,
	pcwf.timezone
ORDER BY
	`ranking`,
	pcwf.country
LIMIT 10;

SELECT
	*
FROM
	pbi_avg_10_lowest_temperatures_europe_2025;

/* ---------------------------------------------------------
 * Analysen weltweit mit Fokus auf Wetterextreme - Aufgabe 2
 -------------------------------------------------------- */

/*
 * Berechne die weltweite Durchschnittstemperatur und erstelle eine View für PowerBI
 */
CREATE OR REPLACE
VIEW pbi_avg_temperature_worldwide_2025 AS 
SELECT
	ROUND(AVG(pcwf.temperature_celsius), 2) AS avg_temperature_worldwide_2025
FROM
	pbi_countries_with_full_2025 pcwf;

SELECT
	*
FROM
	pbi_avg_temperature_worldwide_2025;

/*
 * Berechne die minimale Temperatur weltweit und erstelle eine View für PowerBI
 */
CREATE OR REPLACE
VIEW pbi_min_temperature_worldwide_2025 AS 
SELECT
	MIN(pcwf.temperature_celsius) AS min_temperature_worldwide_2025,
	pcwf.location_name,
	pcwf.country
FROM
	pbi_countries_with_full_2025 pcwf
GROUP BY
	pcwf.location_name,
	pcwf.country
ORDER BY
	min_temperature_worldwide_2025
LIMIT 1;

SELECT
	*
FROM
	pbi_min_temperature_worldwide_2025;

/*
 * Berechne die maximale Temperatur weltweit und erstelle eine View für PowerBI
 */
CREATE OR REPLACE
VIEW pbi_max_temperature_worldwide_2025 AS 
SELECT
	MAX(pcwf.temperature_celsius) AS max_temperature_worldwide_2025,
	pcwf.location_name,
	pcwf.country
FROM
	pbi_countries_with_full_2025 pcwf
GROUP BY
	pcwf.location_name,
	pcwf.country
ORDER BY
	max_temperature_worldwide_2025 DESC
LIMIT 1;

SELECT
	*
FROM
	pbi_max_temperature_worldwide_2025;

/*
 * Finde die 10 Orte mit der höchsten Durchschnittstemperatur weltweit im Jahr 2025
 */
CREATE OR REPLACE
VIEW pbi_10_highest_temperatures_worldwide AS
SELECT
	ROUND(AVG(pcwf.temperature_celsius), 2) AS avg_max_temperatur_celsius,
	pcwf.location_name,
	pcwf.country,
	RANK() OVER(ORDER BY AVG(pcwf.temperature_celsius) DESC) AS `ranking`
FROM
	pbi_countries_with_full_2025 pcwf
WHERE
	EXTRACT(YEAR FROM pcwf.last_updated) = 2025
GROUP BY
	pcwf.location_name,
	pcwf.country
ORDER BY
	avg_max_temperatur_celsius DESC
LIMIT 10;

SELECT
	*
FROM
	pbi_10_highest_temperatures_worldwide;

/*
 * Finde die 10 Orte mit der niedrigsten Durchschnittstemperatur weltweit im Jahr 2025
 */
CREATE OR REPLACE
VIEW pbi_10_lowest_temperatures_worldwide AS
SELECT
	ROUND(AVG(pcwf.temperature_celsius), 2) AS avg_min_temperatur_celsius,
	pcwf.location_name,
	pcwf.country,
	RANK() OVER(ORDER BY AVG(pcwf.temperature_celsius)) AS `ranking`
FROM
	pbi_countries_with_full_2025 pcwf
WHERE
	EXTRACT(YEAR FROM pcwf.last_updated) = 2025
GROUP BY
	pcwf.location_name,
	pcwf.country
ORDER BY
	avg_min_temperatur_celsius
LIMIT 10;

SELECT
	*
FROM
	pbi_10_lowest_temperatures_worldwide;

/* 
 * Finde die weltweit höchste Windgeschwindigkeit einer 2025 auftretenden Windböe
 */
CREATE OR REPLACE
VIEW pbi_highest_wind_gust_worldwide AS
SELECT
	pcwf.gust_kph AS max_gusts_kph,
	pcwf.wind_kph,
	pcwf.location_name,
	pcwf.country,
	pcwf.last_updated
FROM
	pbi_countries_with_full_2025 pcwf
WHERE
	EXTRACT(YEAR FROM pcwf.last_updated) = 2025
ORDER BY
	pcwf.gust_kph DESC
LIMIT 1;

SELECT
	*
FROM
	pbi_highest_wind_gust_worldwide;

/*
 * Finde die 10 Orte mit der weltweit größten Luftverschmutzung mit CO 2025
 */
CREATE OR REPLACE
VIEW pbi_10_countries_with_most_worst_air_quality_worldwide AS
SELECT
	ROUND(AVG(pcwf.air_quality_carbon_monoxide), 2) AS avg_air_quality_carbon_monoxide,
	pcwf.location_name,
	pcwf.country,
	RANK() OVER(ORDER BY AVG(pcwf.air_quality_carbon_monoxide) DESC) AS `ranking`
FROM
	pbi_countries_with_full_2025 pcwf
WHERE
	EXTRACT(YEAR FROM pcwf.last_updated) = 2025
GROUP BY
	pcwf.location_name,
	pcwf.country
ORDER BY
	avg_air_quality_carbon_monoxide DESC
LIMIT 10;

SELECT
	*
FROM
	pbi_10_countries_with_most_worst_air_quality_worldwide;

/*
 * Finde die 10 Orte mit der weltweit niedrigsten Luftverschmutzung mit CO 2025
 */
CREATE OR REPLACE
VIEW pbi_10_countries_with_best_air_quality_worldwide AS
SELECT
	ROUND(AVG(pcwf.air_quality_carbon_monoxide), 2) AS avg_air_quality_carbon_monoxide,
	pcwf.location_name,
	pcwf.country,
	RANK() OVER(ORDER BY AVG(pcwf.air_quality_carbon_monoxide)) AS `ranking`
FROM
	pbi_countries_with_full_2025 pcwf
WHERE
	EXTRACT(YEAR FROM pcwf.last_updated) = 2025
GROUP BY
	pcwf.location_name,
	pcwf.country
ORDER BY
	avg_air_quality_carbon_monoxide
LIMIT 10;

SELECT
	*
FROM
	pbi_10_countries_with_best_air_quality_worldwide;

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
	ROUND((AVG(pcwf.`air_quality_pm2.5` * pcwf.air_quality_pm10) - AVG(pcwf.`air_quality_pm2.5`) * AVG(pcwf.air_quality_pm10)) / 
(STDDEV_POP(pcwf.`air_quality_pm2.5`) * STDDEV_POP(pcwf.air_quality_pm10)), 2) AS c_air_quality_pm2_5_VS_air_quality_pm10
FROM
	pbi_countries_with_full_2025 pcwf
INTO
	@corr_pm2_5_VS_pm10;

SELECT
	@corr_pm2_5_VS_pm10 AS `Correlation between micro dust < 2.5 micrometer and micro dust < 10 micrometer`,
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
	ROUND((AVG(pcwf.air_quality_pm10 * pcwf.temperature_celsius) - AVG(pcwf.air_quality_pm10) * AVG(pcwf.temperature_celsius)) /
(STDDEV_POP(pcwf.air_quality_pm10) * STDDEV_POP(pcwf.temperature_celsius)), 2) AS c_air_quality_pm10_VS_temperature_celsius
FROM
	pbi_countries_with_full_2025 pcwf
INTO
	@corr_pm10_VS_temperature_celsius;

SELECT
	@corr_pm10_VS_temperature_celsius AS `Correlation between micro dust < 10 micrometer and temperature`,
	get_correlation_category(@corr_pm10_VS_temperature_celsius) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen der Menge an Feinstaubpartikeln < 10 Mikrometern
 * und der Niederschlagsmenge?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT
	ROUND((AVG(pcwf.air_quality_pm10 * pcwf.precip_mm) - AVG(pcwf.air_quality_pm10) * AVG(pcwf.precip_mm)) /
(STDDEV_POP(pcwf.air_quality_pm10) * STDDEV_POP(pcwf.precip_mm)), 2) AS c_air_quality_pm10_VS_precip_mm
FROM
	pbi_countries_with_full_2025 pcwf
INTO
	@corr_pm10_VS_precip_mm;

SELECT
	@corr_pm10_VS_precip_mm AS `Correlation value between micro dust < 10 micrometer and amount of rain`,
	get_correlation_category(@corr_pm10_VS_precip_mm) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen der Menge an Feinstaubpartikeln < 10 Mikrometern
 * und der Bewölkung?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT
	ROUND((AVG(pcwf.air_quality_pm10 * pcwf.cloud) - AVG(pcwf.air_quality_pm10) * AVG(pcwf.cloud)) /
(STDDEV_POP(pcwf.air_quality_pm10) * STDDEV_POP(pcwf.cloud)), 2) AS c_air_quality_pm10_VS_cloud
FROM
	pbi_countries_with_full_2025 pcwf
INTO
	@corr_pm10_VS_cloud;

SELECT
	@corr_pm10_VS_cloud AS `Correlation between micro dust < 10 micrometer and amount of clouds`,
	get_correlation_category(@corr_pm10_VS_cloud) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen der Menge an Feinstaubpartikeln < 10 Mikrometern
 * und der Sichtweite in km?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT
	ROUND((AVG(pcwf.air_quality_pm10 * pcwf.visibility_km) - AVG(pcwf.air_quality_pm10) * AVG(pcwf.visibility_km)) /
(STDDEV_POP(pcwf.air_quality_pm10) * STDDEV_POP(pcwf.visibility_km)), 2) AS c_air_quality_pm10_VS_visibility_km
FROM
	pbi_countries_with_full_2025 pcwf
INTO
	@corr_pm10_VS_visibility_km;

SELECT
	@corr_pm10_VS_visibility_km AS `Correlation between micro dust < 10 micrometer and the visibility in km`,
	get_correlation_category(@corr_pm10_VS_visibility_km) AS `Correlation category`;

/* 
 * Analyse weiterer möglicherweise interessanter Zusammenhänge als Zusatz
 */

/*
 * Gibt es einen Zusammenhang zwischen der Sichtweite in km und der Luftfeuchtigkeit?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT
	ROUND((AVG(pcwf.visibility_km * pcwf.humidity) - AVG(pcwf.visibility_km) * AVG(pcwf.humidity)) /
(STDDEV_POP(pcwf.visibility_km) * STDDEV_POP(pcwf.humidity)), 2) AS c_visibility_km_VS_humidity
FROM
	pbi_countries_with_full_2025 pcwf
INTO
	@corr_visibility_VS_humidity;

SELECT
	@corr_visibility_VS_humidity AS `Correlation value between visibility in km and humidity in percent`,
	get_correlation_category(@corr_visibility_VS_humidity) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen der Temperatur in °C und der Luffeuchtigkeit?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT
	ROUND((AVG(pcwf.temperature_celsius * pcwf.humidity) - AVG(pcwf.temperature_celsius) * AVG(pcwf.humidity)) /
(STDDEV_POP(pcwf.temperature_celsius) * STDDEV_POP(pcwf.humidity)), 2) AS c_temperature_celsius_VS_humidity
FROM
	pbi_countries_with_full_2025 pcwf
INTO
	@corr_temperature_VS_humidity;

SELECT
	@corr_temperature_VS_humidity AS `Correlation between temperature and humidity`,
	get_correlation_category(@corr_temperature_VS_humidity) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen der gefühlten Temperatur in °C und der Luftfeuchtigkeit?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT
	ROUND((AVG(pcwf.feels_like_celsius * pcwf.humidity) - AVG(pcwf.feels_like_celsius) * AVG(pcwf.humidity)) /
(STDDEV_POP(pcwf.feels_like_celsius) * STDDEV_POP(pcwf.humidity)), 2) AS c_feels_like_celsius_VS_humidity
FROM
	pbi_countries_with_full_2025 pcwf
INTO
	@corr_feeled_temp_VS_humidity;

SELECT
	@corr_feeled_temp_VS_humidity AS `Correlation between feeled temperature and humidity`,
	get_correlation_category(@corr_feeled_temp_VS_humidity) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen dem Ozon Wert und dem UV Index?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT
	ROUND((AVG(pcwf.air_quality_Ozone * pcwf.uv_index) - AVG(pcwf.air_quality_Ozone) * AVG(pcwf.uv_index)) /
(STDDEV_POP(pcwf.air_quality_Ozone) * STDDEV_POP(pcwf.uv_index)), 2) AS c_ozone_VS_uv_index
FROM
	pbi_countries_with_full_2025 pcwf
INTO
	@corr_ozone_VS_uv_index;

SELECT
	@corr_ozone_VS_uv_index AS `Correlation between ozone and uv index`,
	get_correlation_category(@corr_ozone_VS_uv_index) AS `Correlation category`;

/*
 * Finde den Ort und den Zeitpunkt mit dem höchsten Wert des UV Index weltweit 2025
 */
CREATE OR REPLACE
VIEW pbi_highest_uv_index_worldwide_2025 AS
SELECT
	pcwf.uv_index AS max_uv_index,
	pcwf.location_name,
	pcwf.country
FROM
	pbi_countries_with_full_2025 pcwf
WHERE
	EXTRACT(YEAR FROM pcwf.last_updated) = 2025
ORDER BY
	pcwf.uv_index DESC
LIMIT 1;

SELECT
	*
FROM
	pbi_highest_uv_index_worldwide_2025;

/*
 * Finde alle Orte, die 2025 einen maximalen UV Index von >= 11 aufwiesen.
 * Ab diesem UV Index bekommt man unabhängig von Sonnenschutzmitteln innerhalb
 * von wenigen Minuten einen Sonnenbrand. Die besten Schutzmaßnahmen sind an
 * diesen Orten die vollständige Bedeckung mit Kleidungsstücken oder das Aufhalten
 * ausschließlich in geschlossenen Räumen.
 */
SELECT
	pcwf.uv_index AS max_uv_index,
	pcwf.location_name,
	pcwf.country
FROM
	pbi_countries_with_full_2025 pcwf
WHERE
	EXTRACT(YEAR FROM pcwf.last_updated) = 2025
	AND pcwf.uv_index >= 11
ORDER BY
	pcwf.uv_index DESC;

WITH wind_counts AS (
SELECT
	pcwf.wind_direction,
	COUNT(*) AS count_per_type
FROM
	pbi_countries_with_full_2025 pcwf
WHERE
	location_name = 'Berlin'
	AND EXTRACT(YEAR FROM pcwf.last_updated) = 2025
	AND pcwf.wind_direction IS NOT NULL
GROUP BY
	pcwf.wind_direction
),
total_count AS (
SELECT
	SUM(count_per_type) AS total_rows
FROM
	wind_counts
)
SELECT
	wc.wind_direction,
	wc.count_per_type,
	ROUND((wc.count_per_type * 100.0 / tc.total_rows), 2) AS percentage
FROM
	wind_counts wc
CROSS JOIN total_count tc
ORDER BY
	wc.count_per_type DESC;

/*
 * Finde das durchschnittliche Sonnenbrandrisiko in Berlin 2025 in Prozent heraus
 */
CREATE OR REPLACE
VIEW pbi_sunburn_risk_level_berlin_2025 AS
WITH tb_risk_level AS (
SELECT
	ROUND(pcwf.uv_index) AS uv_index_rounded, 
	COUNT(get_uv_risk(ROUND(pcwf.uv_index))) AS ct_uv_risk_level,
	get_uv_risk(ROUND(pcwf.uv_index)) AS uv_risk_level
FROM
	pbi_countries_with_full_2025 pcwf
WHERE
	pcwf.location_name LIKE '%berlin%'
	AND EXTRACT(YEAR FROM pcwf.last_updated) = 2025
GROUP BY
	uv_index_rounded,
	pcwf.uv_index,
	uv_risk_level
ORDER BY 
	CASE
		WHEN ROUND(pcwf.uv_index) >= 11 THEN 0
		WHEN ROUND(pcwf.uv_index) BETWEEN 8 AND 10 THEN 1
		WHEN ROUND(pcwf.uv_index) BETWEEN 6 AND 7 THEN 2
		WHEN ROUND(pcwf.uv_index) BETWEEN 3 AND 5 THEN 3
		WHEN ROUND(pcwf.uv_index) BETWEEN 1 AND 2 THEN 4
		ELSE 5
	END
),
tb_uv_risk_level_count AS (
SELECT
	rl.uv_index_rounded AS uv_index_rounded,
	SUM(rl.ct_uv_risk_level) AS ct_uv_risk_level,
	rl.uv_risk_level AS uv_risk_level
FROM
	tb_risk_level rl
GROUP BY
	rl.uv_index_rounded,
	rl.uv_risk_level
)
SELECT
	SUM(urlc.ct_uv_risk_level) AS sum_uv_risk_level,
	urlc.uv_risk_level,
	ROUND(SUM(urlc.ct_uv_risk_level) * 100 / 365, 2) AS percentual_risk_level
FROM
	tb_uv_risk_level_count urlc
GROUP BY
	urlc.uv_risk_level;

SELECT
	*
FROM
	pbi_sunburn_risk_level_berlin_2025;