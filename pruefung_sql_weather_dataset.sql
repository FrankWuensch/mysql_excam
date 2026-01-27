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
CREATE FUNCTION get_correlation_category(value DECIMAL(3, 2))
RETURNS VARCHAR(20)
DETERMINISTIC
BEGIN 
    IF ABS(value) >= 0.5 THEN  -- ABS verwendet den Betrag der Zahl, also ohne Beachtung des Vorzeichens
        RETURN 'strong correlation';
    ELSEIF ABS(value) >= 0.3 THEN
        RETURN 'medium correlation';
    ELSEIF ABS(value) >= 0.1 THEN
        RETURN 'small correlation';
    ELSE
        RETURN 'no significant correlation';
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
		RETURN 'extreme risk';
	ELSEIF value BETWEEN 8 AND 10 THEN 
		RETURN 'very high risk';
	ELSEIF value BETWEEN 6 AND 7 THEN 
		RETURN 'high risk';
	ELSEIF value BETWEEN 3 AND 5 THEN 
		RETURN 'medium risk';
	ELSEIF value BETWEEN 1 AND 2 THEN 
		RETURN 'low risk';
	ELSE 
		RETURN 'no risk';
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
		RETURN 'winter';
	ELSEIF value BETWEEN DATE('2025-03-20') AND DATE('2025-06-20') THEN
		RETURN 'spring';
	ELSEIF value BETWEEN DATE('2025-06-21') AND DATE('2025-09-21') THEN
		RETURN 'summer';
	ELSEIF value BETWEEN DATE('2025-09-22') AND DATE('2025-12-20') THEN
		RETURN 'autumn';
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
		RETURN 'very high';
	ELSEIF value BETWEEN 5.0 AND 7.4 THEN 
		RETURN 'high';
	ELSEIF value BETWEEN 2.5 AND 4.9 THEN 
		RETURN 'medium';
	ELSEIF value BETWEEN 0.0 AND 2.4 THEN
		RETURN 'low';
	END IF;
END //

DELIMITER ;

/*
 * Funktionstests
 */
SELECT get_correlation_category(0.5)  AS correlation_category;  -- Erwartet: 'strong correlation'
SELECT get_correlation_category(0.3)  AS correlation_category;  -- Erwartet: 'medium correlation'
SELECT get_correlation_category(0.1)  AS correlation_category;  -- Erwartet: 'small correlation'
SELECT get_correlation_category(-0.1) AS correlation_category;  -- Erwartet: 'small correlation'
SELECT get_correlation_category(-0.3) AS correlation_category;  -- Erwartet: 'medium correlation'
SELECT get_correlation_category(-0.5) AS correlation_category;  -- Erwartet: 'strong correlation'

SELECT get_uv_risk(7) AS uv_risk_level;       -- Erwartet: 'high risk'

SELECT get_season('2024-12-21') AS season;    -- Erwartet: 'winter'
SELECT get_season('2024-12-20') AS season;    -- Erwartet: NULL

SELECT get_month('2025-01-04') AS `month`;    -- Erwartet: 'January'
SELECT get_month('2025-03-20') AS `month`;    -- Erwartet: 'March'
SELECT get_month('2024-12-21') AS `month`;    -- Erwartet: 'December'

SELECT get_gb_defra_category(5) AS category;  -- Erwartet: 'high'

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

/*
 * Zähle alle Länder innerhalb der europäischen Zeitzone, die vollständige Daten
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
SELECT gwr.country, 
gwr.timezone, 
ROUND(AVG(gwr.temperature_celsius), 2) AS avg_temperature_celsius,
ROUND(AVG(gwr.wind_kph)) AS avg_wind_kph,
ROUND(AVG(gwr.gust_kph)) AS avg_gusts_kph,
ROUND(AVG(gwr.pressure_mb), 1) AS avg_pressure_millibars,
ROUND(AVG(gwr.humidity), 2) AS avg_percentage_humidity,
ROUND(AVG(gwr.visibility_km)) AS avg_visibility_km,
ROUND(AVG(gwr.cloud), 2) AS avg_percentage_cloud_cover,
ROUND(AVG(gwr.feels_like_celsius), 2) AS avg_feels_like_celsios,
ROUND(AVG(gwr.uv_index), 1) AS avg_uv_index
FROM GlobalWeatherRepository gwr
WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025
GROUP BY gwr.country, gwr.timezone
ORDER BY 
CASE 
	WHEN gwr.timezone LIKE '%europe%' THEN 0
	ELSE 1
END, gwr.country, gwr.timezone;


/* ---------------------------------------------------
 * Analysen deutschlandweit und europaweit - Aufgabe 1
 -------------------------------------------------- */


/* 
 * Erstellen einer VIEW, die alle Wetterdaten für das Jahr 2025 in Deutschland speichert
 * Verwendung für Analysen, die sich auf die Monate oder das gesamte Jahr beziehen
 */
CREATE OR REPLACE VIEW v_weather_germany_2025 AS (
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
	get_month(DATE_FORMAT(gwr.last_updated, '%Y-%m-%d')) AS `month`
	FROM GlobalWeatherRepository gwr
	WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025
	AND gwr.location_name LIKE '%berlin%'
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
	get_season(DATE_FORMAT(gwr.last_updated, '%Y-%m-%d')) AS season
	FROM GlobalWeatherRepository gwr
	WHERE DATE_FORMAT(gwr.last_updated, '%Y-%m-%d') BETWEEN DATE('2024-12-21') AND DATE('2025-12-20')
	AND gwr.location_name LIKE '%berlin%'
);

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
	WHEN vws.season LIKE 'win%' THEN 0
	WHEN vws.season LIKE 'spr%' THEN 1
	WHEN vws.season LIKE 'sum%' THEN 2
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
	WHEN vwg.`month` LIKE 'Mar%' THEN 2
	WHEN vwg.`month` LIKE 'Apr%' THEN 3
	WHEN vwg.`month` LIKE 'May'  THEN 4
	WHEN vwg.`month` LIKE 'Jun%' THEN 5
	WHEN vwg.`month` LIKE 'Jul%' THEN 6
	WHEN vwg.`month` LIKE 'Aug%' THEN 7
	WHEN vwg.`month` LIKE 'Sep%' THEN 8
	WHEN vwg.`month` LIKE 'Oct%' THEN 9
	WHEN vwg.`month` LIKE 'Nov%' THEN 10
	ELSE 11
END;

/*
 * Zähle die Tage in Deutschland je nach Luftqualitätsindex
 * und gruppiere sie nach Monaten zur Einschätzung der Luftqualität in Berlin 2025
 * pro Monat
 */
WITH tb_air_quality AS (
	SELECT gwr.location_name, 
	get_month(DATE_FORMAT(gwr.last_updated, '%Y-%m-%d')) AS `month`,
	get_gb_defra_category(gwr.`air_quality_gb-defra-index`) AS air_quality_badness_category,
	COUNT(get_gb_defra_category(gwr.`air_quality_gb-defra-index`)) AS ct_air_quality_category
	FROM GlobalWeatherRepository gwr 
	WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025
	AND gwr.location_name LIKE '%berlin%'
	GROUP BY `month`, gwr.`air_quality_gb-defra-index`, gwr.location_name
)
SELECT aq.location_name, 
aq.`month`,
aq.air_quality_badness_category as air_quality_badness_category,
SUM(aq.ct_air_quality_category) AS ct_air_quality_category
FROM tb_air_quality aq
GROUP BY aq.air_quality_badness_category, aq.location_name, aq.`month`
ORDER BY 
CASE
	WHEN `month` LIKE 'Jan%' THEN 0
	WHEN `month` LIKE 'Feb%' THEN 1
	WHEN `month` LIKE 'Mar%' THEN 2
	WHEN `month` LIKE 'Apr%' THEN 3
	WHEN `month` LIKE 'May'  THEN 4
	WHEN `month` LIKE 'Jun%' THEN 5
	WHEN `month` LIKE 'Jul%' THEN 6
	WHEN `month` LIKE 'Aug%' THEN 7
	WHEN `month` LIKE 'Sep%' THEN 8
	WHEN `month` LIKE 'Oct%' THEN 9
	WHEN `month` LIKE 'Nov%' THEN 10
	ELSE 11
END,
CASE
	WHEN aq.air_quality_badness_category = 'very high' THEN 0
	WHEN aq.air_quality_badness_category = 'high' THEN 1 
	WHEN aq.air_quality_badness_category = 'medium' THEN 2 
	WHEN aq.air_quality_badness_category = 'low' THEN 3
END;

/*
 * Zähle die Tage in Australien je nach Luftqualitätsindex
 * und gruppiere sie nach Monaten zur Einschätzung der Luftqualität in Australien 2025
 * pro Monat
 * 
 * Erwartetes Ergebnis:
 * Erhöhte Werte in den Monaten Januar, März, April und Dezember wegen schwerer Waldbrände
 * in Victoria, Westaustralien und New South Wales
 */
WITH tb_air_quality AS (
	SELECT gwr.location_name,
	get_month(DATE_FORMAT(gwr.last_updated, '%Y-%m-%d')) AS `month`,
	get_gb_defra_category(gwr.`air_quality_gb-defra-index`) AS air_quality_badness_category,
	COUNT(get_gb_defra_category(gwr.`air_quality_gb-defra-index`)) AS ct_air_quality_category
	FROM GlobalWeatherRepository gwr 
	WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025
	AND gwr.country LIKE '%australia%'
	GROUP BY `month`, gwr.`air_quality_gb-defra-index`, gwr.location_name
)
SELECT aq.location_name, 
aq.`month`,
aq.air_quality_badness_category as air_quality_badness_category,
SUM(aq.ct_air_quality_category) AS ct_air_quality_category
FROM tb_air_quality aq
GROUP BY aq.air_quality_badness_category, aq.location_name, aq.`month`
ORDER BY 
CASE
	WHEN `month` LIKE 'Jan%' THEN 0
	WHEN `month` LIKE 'Feb%' THEN 1
	WHEN `month` LIKE 'Mar%' THEN 2
	WHEN `month` LIKE 'Apr%' THEN 3
	WHEN `month` LIKE 'May'  THEN 4
	WHEN `month` LIKE 'Jun%' THEN 5
	WHEN `month` LIKE 'Jul%' THEN 6
	WHEN `month` LIKE 'Aug%' THEN 7
	WHEN `month` LIKE 'Sep%' THEN 8
	WHEN `month` LIKE 'Oct%' THEN 9
	WHEN `month` LIKE 'Nov%' THEN 10
	ELSE 11
END,
CASE
	WHEN aq.air_quality_badness_category = 'very high' THEN 0
	WHEN aq.air_quality_badness_category = 'high' THEN 1 
	WHEN aq.air_quality_badness_category = 'medium' THEN 2 
	WHEN aq.air_quality_badness_category = 'low' THEN 3
END;

/*
 * Finde die 10 heißesten Orte in der europäischen Zeitzone im Jahr 2025
 */
SELECT vgt.country, 
ROUND(AVG(vgt.avg_temperature_celsius), 2) AS avg_temperature_celsius,
DENSE_RANK() OVER(ORDER BY AVG(vgt.avg_temperature_celsius) DESC) AS `ranking`
FROM v_grouped_timezones vgt
WHERE vgt.timezone LIKE '%europe%'
GROUP BY vgt.country
ORDER BY `ranking`, vgt.country
LIMIT 10;

/*
 * Finde die 10 kältesten Orte in der europäischen Zeitzone im Jahr 2025
 */
SELECT vgt.country, 
ROUND(AVG(vgt.avg_temperature_celsius), 2) AS avg_temperature_celsius,
DENSE_RANK() OVER(ORDER BY AVG(vgt.avg_temperature_celsius)) AS `ranking`
FROM v_grouped_timezones vgt 
WHERE vgt.timezone LIKE '%europe%'
GROUP BY vgt.country
ORDER BY `ranking`, vgt.country
LIMIT 10;


/* ---------------------------------------------------------
 * Analysen weltweit mit Fokus auf Wetterextreme - Aufgabe 2
 -------------------------------------------------------- */


/*
 * Finde die 10 Orte mit der höchsten Durchschnittstemperatur weltweit im Jahr 2025
 */
SELECT gwr.temperature_celsius AS avg_min_temperatur_celsius,
gwr.location_name,
gwr.country,
DATE_FORMAT(gwr.last_updated, '%M %Y') AS `date`
FROM GlobalWeatherRepository gwr
WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025
ORDER BY gwr.temperature_celsius DESC
LIMIT 10;

/*
 * Finde die 10 Orte mit der niedrigsten Durchschnittstemperatur weltweit im Jahr 2025
 */
SELECT gwr.temperature_celsius AS avg_min_temperatur_celsius,
gwr.location_name,
gwr.country,
DATE_FORMAT(gwr.last_updated, '%M %Y') AS `date`
FROM GlobalWeatherRepository gwr
WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025
ORDER BY gwr.temperature_celsius 
LIMIT 10;

/* 
 * Finde die weltweit höchste Windgeschwindigkeit einer 2025 auftretenden Windböe
 */
SELECT gwr.gust_kph AS max_gusts_kph,
gwr.wind_kph,
gwr.location_name,
gwr.country,
gwr.last_updated
FROM GlobalWeatherRepository gwr 
WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025
ORDER BY gwr.gust_kph DESC 
LIMIT 1;

/*
 * Finde die 10 Orte mit der weltweit größten Luftverschmutzung mit CO 2025
 */
SELECT ROUND(AVG(gwr.air_quality_carbon_monoxide), 2) AS avg_air_quality_carbon_monoxide,
gwr.location_name,
gwr.country
FROM GlobalWeatherRepository gwr 
WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025
GROUP BY gwr.location_name, gwr.country
ORDER BY avg_air_quality_carbon_monoxide DESC 
LIMIT 10;

/*
 * Finde die 10 Orte mit der weltweit niedrigsten Luftverschmutzung mit CO 2025
 */
SELECT ROUND(AVG(gwr.air_quality_carbon_monoxide), 2) AS avg_air_quality_carbon_monoxide,
gwr.location_name,
gwr.country
FROM GlobalWeatherRepository gwr 
WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025
GROUP BY gwr.location_name, gwr.country
ORDER BY avg_air_quality_carbon_monoxide
LIMIT 10;

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
ROUND((AVG(gwr.`air_quality_pm2.5` * gwr.air_quality_pm10) - AVG(gwr.`air_quality_pm2.5`) * AVG(gwr.air_quality_pm10)) / 
(STDDEV_POP(gwr.`air_quality_pm2.5`) * STDDEV_POP(gwr.air_quality_pm10)), 2) AS c_air_quality_pm2_5_VS_air_quality_pm10
FROM GlobalWeatherRepository gwr INTO @corr_pm2_5_VS_pm10;

SELECT @corr_pm2_5_VS_pm10 AS `Correlation value between micro dust < 2.5 micrometer and micro dust < 10 micrometer`,
get_correlation_category(@corr_pm2_5_VS_pm10) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen der Sichtweite in km und der Luftfeuchtigkeit?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT 
ROUND((AVG(gwr.visibility_km * gwr.humidity) - AVG(gwr.visibility_km) * AVG(gwr.humidity)) /
(STDDEV_POP(gwr.visibility_km) * STDDEV_POP(gwr.humidity)), 2) AS c_visibility_km_VS_humidity
FROM GlobalWeatherRepository gwr INTO @corr_visibility_VS_humidity;

SELECT @corr_visibility_VS_humidity AS `Correlation value between visibility in km and humidity in percent`,
get_correlation_category(@corr_visibility_VS_humidity) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen der Temperatur in °C und der Luffeuchtigkeit?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT 
ROUND((AVG(gwr.temperature_celsius * gwr.humidity) - AVG(gwr.temperature_celsius) * AVG(gwr.humidity)) /
(STDDEV_POP(gwr.temperature_celsius) * STDDEV_POP(gwr.humidity)), 2) AS c_temperature_celsius_VS_humidity 
FROM GlobalWeatherRepository gwr INTO @corr_temperature_VS_humidity;

SELECT @corr_temperature_VS_humidity AS `Correlation value between temperature in celsius and humidity in percent`,
get_correlation_category(@corr_temperature_VS_humidity) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen der gefühlten Temperatur in °C und der Luftfeuchtigkeit?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT 
ROUND((AVG(gwr.feels_like_celsius * gwr.humidity) - AVG(gwr.feels_like_celsius) * AVG(gwr.humidity)) /
(STDDEV_POP(gwr.feels_like_celsius) * STDDEV_POP(gwr.humidity)), 2) AS c_feels_like_celsius_VS_humidity 
FROM GlobalWeatherRepository gwr INTO @corr_feeled_temp_VS_humidity;

SELECT @corr_feeled_temp_VS_humidity AS `Correlation value between feeled temperature in celsius and humidity in percent`,
get_correlation_category(@corr_feeled_temp_VS_humidity) AS `Correlation category`;

/*
 * Gibt es einen Zusammenhang zwischen dem Ozon Wert und dem UV Index?
 * Wie stark ist dieser Zusammenhang?
 */
SELECT 
ROUND((AVG(gwr.air_quality_Ozone * gwr.uv_index) - AVG(gwr.air_quality_Ozone) * AVG(gwr.uv_index)) /
(STDDEV_POP(gwr.air_quality_Ozone) * STDDEV_POP(gwr.uv_index)), 2) AS c_ozone_VS_uv_index
FROM GlobalWeatherRepository gwr INTO @corr_ozone_VS_uv_index;

SELECT @corr_ozone_VS_uv_index AS `Correlation value between ozone and uv index`,
get_correlation_category(@corr_ozone_VS_uv_index) AS `Correlation category`;

/*
 * Finde den Ort und den Zeitpunkt mit dem höchsten Wert des UV Index weltweit 2025
 */
SELECT MAX(gwr.uv_index) AS max_uv_index,
gwr.location_name,
gwr.country
FROM GlobalWeatherRepository gwr
WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025
GROUP BY gwr.location_name, gwr.country
ORDER BY MAX(gwr.uv_index) DESC
LIMIT 1;

/*
 * Finde alle Orte, die 2025 einen maximalen UV Index von >= 11 aufwiesen.
 * Ab diesem UV Index bekommt man unabhängig von Sonnenschutzmitteln innerhalb
 * von wenigen Minuten einen Sonnenbrand. Die besten Schutzmaßnahmen sind an
 * diesen Orten die vollständige Bedeckung mit Kleidungsstücken oder das Aufhalten
 * ausschließlich in geschlossenen Räumen.
 */

SELECT MAX(gwr.uv_index) AS max_uv_index,
gwr.location_name,
gwr.country
FROM GlobalWeatherRepository gwr
WHERE EXTRACT(YEAR FROM gwr.last_updated) = 2025
AND gwr.uv_index >= 11
GROUP BY gwr.location_name, gwr.country
ORDER BY MAX(gwr.uv_index) DESC;

/*
 * Finde die Rangordnung der verschiedenen Windrichtungen in Berlin 2025 heraus
 * Erwartetes Ergebnis: 
 * Westwind sollte an Platz 1 in der Liste erscheinen, da dies die bekannte Wetterseite ist.
 * 
 * Hierzu wird eine neue Spalte hinter der Windrichtung eingefügt, in der nur die Aufteilung
 * IN Nord, Ost, Süd und West erfolgt.
 * Erwartetes Ergebnis: 
 * Eingruppierung sollte identisch sein zu N, E, S und W in der Spalte wind_direction
 */
ALTER TABLE GlobalWeatherRepository ADD COLUMN wind_direction_group VARCHAR(8) after wind_direction;

/* 
 * Safe update mode ausschalten, da ich mehrere Werte gleichzeitig aktualisieren möchte
 */
SET sql_safe_updates = 0;

UPDATE GlobalWeatherRepository
SET wind_direction_group = 
CASE 
    -- North: 348.75° bis 360° und 0° bis 11.25°
    WHEN wind_degree >= 348.75 OR wind_degree <= 11.25 THEN 'North'
    -- East: 78.75° bis 101.25°
    WHEN wind_degree BETWEEN 78.75 AND 101.25 THEN 'East'
    -- South: 168.75° bis 191.25°
    WHEN wind_degree BETWEEN 168.75 AND 191.25 THEN 'South'
    -- West: 258.75° bis 281.25°
    WHEN wind_degree BETWEEN 258.75 AND 281.25 THEN 'West'
    ELSE NULL
END;

/* 
 * Safe update mode wieder einschalten
 */
SET sql_safe_updates = 1;

WITH wind_counts AS (
    SELECT 
        wind_direction_group,
        COUNT(*) AS count_per_type
    FROM GlobalWeatherRepository
    WHERE location_name = 'Berlin'
    AND EXTRACT(YEAR FROM last_updated) = 2025
    AND wind_direction_group IS NOT NULL
    GROUP BY wind_direction_group
),
total_count AS (
    SELECT SUM(count_per_type) AS total_rows
    FROM wind_counts
)
SELECT 
    wc.wind_direction_group,
    wc.count_per_type,
    ROUND((wc.count_per_type * 100.0 / tc.total_rows), 2) AS percentage
FROM wind_counts wc
CROSS JOIN total_count tc
ORDER BY wc.count_per_type DESC;

/*
 * Finde das durchschnittliche Sonnenbrandrisiko in Berlin 2025 in Prozent heraus
 */
WITH tb_risk_level AS (
	SELECT ROUND(gwr.uv_index) AS uv_index_rounded, 
	COUNT(get_uv_risk(ROUND(gwr.uv_index))) AS ct_uv_risk_level,
	get_uv_risk(ROUND(gwr.uv_index)) AS uv_risk_level
	FROM GlobalWeatherRepository gwr 
	WHERE gwr.location_name LIKE '%berlin%'
	AND EXTRACT(YEAR FROM gwr.last_updated) = 2025
	GROUP BY uv_index_rounded, gwr.uv_index, uv_risk_level
	ORDER BY 
	CASE
		WHEN ROUND(gwr.uv_index) >= 11 THEN 0
		WHEN ROUND(gwr.uv_index) BETWEEN 8 AND 10 THEN 1
		WHEN ROUND(gwr.uv_index) BETWEEN 6 AND 7 THEN 2
		WHEN ROUND(gwr.uv_index) BETWEEN 3 AND 5 THEN 3
		WHEN ROUND(gwr.uv_index) BETWEEN 1 AND 2 THEN 4
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