# Abschlussprojekt MySQL
## Analyse Wetterdaten weltweit
### Quelle
[World Weather Repository](https://www.kaggle.com/datasets/nelgiriyewithana/global-weather-repository) von [Kaggle.com](https://www.kaggle.com/)

### Zielsetzungen der Analyse
- Europäsche Zeitzone
    - Deutschland
        - Auffälligkeiten im Jahresverlauf (monatlich und Quartal) bzgl. 
            - Anzahl sonnige Tage
            - Anzahl bewölkte Tage
            - Anzahl Tage mit Niederschlag
    - 10 Orte mit der höchsten Jahresdurchschnittstemperatur
    - 10 Orte mit der niedrigsten Jahresdurchschnittstemperatur
    - Faktoren für hohe oder niedrige Luftverschmutzung (Korrelation?)
- Exploration hinsichtlich der Jahreszeiten
    - Winter    -> 21. Dezember 2024 bis 19. März 2025
    - Frühling  -> 20. März bis 20. Juni 2025
    - Sommer    -> 21. Juni bis 21. September 2025
    - Herbst    -> 22. September bis 20. Dezember 2025
- Tiefsttemperatur weltweit inkl. Zeitpunkt und Ort
- Höchsttemperatur weltweit inkl. Zeitpunkt und Ort

### Konkrete Fragestellungen
- Frage 1
    - Wie verändert sich das Wetterprofil in Deutschland im Jahresverlauf 2025 und lassen sich klare saisonale Muster erkennen?
        - Anzahl sonniger Tage
        - Anzahl bewölkter Tage
        - Anzahl Tage mit Niederschlag
        - Welche 10 Orte haben die höchste bzw. niedrigste Jahresdurchschnittstemperatur 2025 innerhalb der europäischen Zeitzone?
        - Bewertung des Sonnenbrandrisikos in Deutschland
        - Aggregationen
            - monatlich
            - quartalsweise
            - nach definierten Jahreszeiten (siehe [hier](#zielsetzungen-der-analyse))
        - Visualisierung von Trends & Auffälligkeiten (Power BI)
- Frage 2
    - Welche Orte weltweit weisen extreme Temperatur- und Luftverschmutzungsprofile auf und welche Wetterfaktoren stehen damit in Zusammenhang?
        - Welche 10 Orte haben die höchste bzw. niedrigste Jahresdurchschnittstemperatur?
        - Wo traten die globale Höchst- und Tiefsttemperatur auf?
        - Besteht ein Zusammenhang zwischen Luftverschmutzung und Wetterparametern wie Temperatur, Niederschlag oder Bewölkung?

### Begründung für die Wahl des Datensatzes und die Wahl der Fragestellungen
- Datensatz eigenet sich aufgrund der guten Datenlage für das Jahr 2025 hervorragend für tiefgreifende Analysen 
- Frage 1 zeigt regionale & saisionale Auffälligkeiten in Deutschland
- Frage 2 ist auf global & extremwetterorientiert ausgerichtet