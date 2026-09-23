-- ============================================================================
-- PROJEKT ZALICZENIOWY: SKLEP E-COMMERCE (ETAP 1 - SQL BAZA DANYCH)
-- AUTOR: [Twoje Imię i Nazwisko / Numer Indeksu]
-- ============================================================================

-- ----------------------------------------------------------------------------
-- SEKCJA 1: INICJALIZACJA BAZY DANYCH
-- ----------------------------------------------------------------------------
CREATE DATABASE IF NOT EXISTS `sklep_ecommerce`;
USE `sklep_ecommerce`;

-- ----------------------------------------------------------------------------
-- SEKCJA 2: STRUKTURA TABEL (DDL) Z WIĘZAMI SPÓJNOŚCI
-- Kolejność tworzenia tabel wynika z hierarchii kluczy obcych (FOREIGN KEY)
-- ----------------------------------------------------------------------------

-- 1. Tabela Słownikowa: Kraje
CREATE TABLE `kraje` (
  `id_kraju` int(11) NOT NULL AUTO_INCREMENT,
  `nazwa_kraju` varchar(100) NOT NULL,
  PRIMARY KEY (`id_kraju`),
  UNIQUE KEY `nazwa_kraju` (`nazwa_kraju`)
) ENGINE=InnoDB AUTO_INCREMENT=25 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 2. Tabela Słownikowa: Statusy Zamówień
CREATE TABLE `statusy_zamowien` (
  `id_statusu` int(11) NOT NULL,
  `nazwa_statusu` varchar(50) NOT NULL,
  PRIMARY KEY (`id_statusu`),
  UNIQUE KEY `nazwa_statusu` (`nazwa_statusu`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 3. Tabela Słownikowa: Produkty
CREATE TABLE `produkty` (
  `kod_produktu` varchar(50) NOT NULL,
  `opis_produktu` varchar(255) NOT NULL,
  PRIMARY KEY (`kod_produktu`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 4. Tabela Powiązana: Klienci
CREATE TABLE `klienci` (
  `id_klienta` int(11) NOT NULL,
  `id_kraju` int(11) NOT NULL,
  PRIMARY KEY (`id_klienta`),
  KEY `id_kraju` (`id_kraju`),
  CONSTRAINT `klienci_ibfk_1` FOREIGN KEY (`id_kraju`) REFERENCES `kraje` (`id_kraju`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

-- 5. Główna Tabela Faktów: Transakcje (wraz z regułami CHECK)
CREATE TABLE `transakcje` (
  `id_transakcji` int(11) NOT NULL AUTO_INCREMENT,
  `numer_faktury` int(11) NOT NULL,
  `kod_produktu` varchar(50) NOT NULL,
  `id_klienta` int(11) DEFAULT NULL,
  `id_statusu` int(11) NOT NULL,
  `data_transakcji` datetime NOT NULL,
  `ilosc` int(11) NOT NULL,
  `cena_jednostkowa` decimal(10,2) NOT NULL,
  PRIMARY KEY (`id_transakcji`),
  KEY `kod_produktu` (`kod_produktu`),
  KEY `id_klienta` (`id_klienta`),
  KEY `id_statusu` (`id_statusu`),
  CONSTRAINT `transakcje_ibfk_1` FOREIGN KEY (`kod_produktu`) REFERENCES `produkty` (`kod_produktu`),
  CONSTRAINT `transakcje_ibfk_2` FOREIGN KEY (`id_klienta`) REFERENCES `klienci` (`id_klienta`),
  CONSTRAINT `transakcje_ibfk_3` FOREIGN KEY (`id_statusu`) REFERENCES `statusy_zamowien` (`id_statusu`),
  CONSTRAINT `check_cena` CHECK (`cena_jednostkowa` >= 0.00),
  CONSTRAINT `check_ilosc_nie_zero` CHECK (`ilosc` <> 0)
) ENGINE=InnoDB AUTO_INCREMENT=58962 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;


-- ----------------------------------------------------------------------------
-- SEKCJA 3: WIDOK ANALITYCZNY (VIEW) DLA POWER BI / ZASILENIE CSV
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW v_dane_analityczne AS
SELECT 
    t.id_transakcji AS id_transakcji,
    t.numer_faktury AS numer_faktury,
    t.data_transakcji AS data_transakcji,
    t.ilosc AS ilosc,
    t.cena_jednostkowa AS cena_jednostkowa,
    ROUND(t.ilosc * t.cena_jednostkowa, 2) AS wartosc_pozycji,
    p.kod_produktu AS kod_produktu,
    CASE 
        WHEN p.opis_produktu = '?' OR p.opis_produktu = 'Brak opisu' THEN CONCAT('Nieznany Produkt (', p.kod_produktu, ')')
        ELSE p.opis_produktu 
    END AS nazwa_produktu,
    IFNULL(t.id_klienta, 0) AS id_klienta,
    IFNULL(kr.nazwa_kraju, 'Niezdefiniowany Kraj') AS kraj_klienta,
    IFNULL(sz.nazwa_statusu, 'Nieznany Status') AS status_zamowienia
FROM transakcje t
LEFT JOIN produkty p ON t.kod_produktu = p.kod_produktu
LEFT JOIN klienci kl ON t.id_klienta = kl.id_klienta
LEFT JOIN kraje kr ON kl.id_kraju = kr.id_kraju
LEFT JOIN statusy_zamowien sz ON t.id_statusu = sz.id_statusu
WHERE t.data_transakcji IS NOT NULL AND t.data_transakcji != '0000-00-00';


-- ----------------------------------------------------------------------------
-- SEKCJA 4: ZESTAW 20 ZAAWANSOWANYCH ZAPYTAŃ ANALITYCZNYCH (SQL BI)
-- ----------------------------------------------------------------------------

-- 1. Ogólny przychód i liczba transakcji per kraj (Złączenia i agregacja)
SELECT 
    kr.nazwa_kraju AS 'Kraj',
    COUNT(DISTINCT t.numer_faktury) AS 'Liczba Faktur',
    SUM(t.ilosc) AS 'Sprzedane Sztuki',
    SUM(ROUND(t.ilosc * t.cena_jednostkowa, 2)) AS 'Calkowity Przychod'
FROM transakcje t
JOIN klienci kl ON t.id_klienta = kl.id_klienta
JOIN kraje kr ON kl.id_kraju = kr.id_kraju
WHERE t.id_statusu = 1
GROUP BY kr.nazwa_kraju
ORDER BY SUM(t.ilosc * t.cena_jednostkowa) DESC;
 
-- 2. Średnia wartość faktury (koszyka zakupowego) per kraj
SELECT 
    kr.nazwa_kraju AS 'Kraj',
    ROUND(SUM(t.ilosc * t.cena_jednostkowa) / COUNT(DISTINCT t.numer_faktury), 2) AS 'Srednia Wartosc Koszyka'
FROM transakcje t
JOIN klienci kl ON t.id_klienta = kl.id_klienta
JOIN kraje kr ON kl.id_kraju = kr.id_kraju
WHERE t.id_statusu = 1
GROUP BY kr.nazwa_kraju
ORDER BY `Srednia Wartosc Koszyka` DESC;
 
-- 3. Przychody w podziale na kwartały (Analiza trendu czasowego)
SELECT 
    YEAR(t.data_transakcji) AS 'Rok',
    QUARTER(t.data_transakcji) AS 'Kwartal',
    COUNT(DISTINCT t.numer_faktury) AS 'Liczba Zamowien',
    SUM(ROUND(t.ilosc * t.cena_jednostkowa, 2)) AS 'Przychod Kwartalny'
FROM transakcje t
WHERE t.id_statusu = 1 
  AND t.data_transakcji IS NOT NULL 
  AND t.data_transakcji != '0000-00-00'
GROUP BY YEAR(t.data_transakcji), QUARTER(t.data_transakcji)
ORDER BY Rok ASC, Kwartal ASC;
 
-- 4. Ranking lat pod względem wygenerowanego zysku
SELECT 
    YEAR(t.data_transakcji) AS 'Rok',
    SUM(t.ilosc) AS 'Liczba Sprzedanych Produktow',
    SUM(ROUND(t.ilosc * t.cena_jednostkowa, 2)) AS 'Przychod Roczny'
FROM transakcje t
WHERE t.id_statusu = 1
  AND t.data_transakcji IS NOT NULL 
  AND t.data_transakcji != '0000-00-00'
GROUP BY YEAR(t.data_transakcji)
ORDER BY `Przychod Roczny` DESC;
 
-- 5. Udział procentowy przychodów danego kraju w całości sprzedaży (Podzapytanie nieskorelowane)
SELECT 
    kr.nazwa_kraju AS 'Kraj',
    SUM(ROUND(t.ilosc * t.cena_jednostkowa, 2)) AS 'Przychod Kraju',
    ROUND((SUM(t.ilosc * t.cena_jednostkowa) / (SELECT SUM(ilosc * cena_jednostkowa) FROM transakcje WHERE id_statusu = 1)) * 100, 2) AS 'Procent Udzialu %'
FROM transakcje t
JOIN klienci kl ON t.id_klienta = kl.id_klienta
JOIN kraje kr ON kl.id_kraju = kr.id_kraju
WHERE t.id_statusu = 1
GROUP BY kr.nazwa_kraju
ORDER BY `Przychod Kraju` DESC;
 
-- 6. TOP 10 najbardziej dochodowych produktów (Generowanie największego obrotu)
SELECT 
    t.kod_produktu AS 'Kod Produktu',
    p.opis_produktu AS 'Nazwa Produktu',
    SUM(t.ilosc) AS 'Suma Sprzedanych Sztuk',
    SUM(ROUND(t.ilosc * t.cena_jednostkowa, 2)) AS 'Laczny Przychod'
FROM transakcje t
JOIN produkty p ON t.kod_produktu = p.kod_produktu
WHERE t.id_statusu = 1
GROUP BY t.kod_produktu, p.opis_produktu
ORDER BY SUM(t.ilosc * t.cena_jednostkowa) DESC
LIMIT 10;
 
-- 7. TOP 10 najczęściej kupowanych produktów (Liczba wystąpień na fakturach)
SELECT 
    t.kod_produktu AS 'Kod Produktu',
    p.opis_produktu AS 'Nazwa Produktu',
    COUNT(t.id_transakcji) AS 'Liczba Transakcji'
FROM transakcje t
JOIN produkty p ON t.kod_produktu = p.kod_produktu
WHERE t.id_statusu = 1
GROUP BY t.kod_produktu, p.opis_produktu
ORDER BY `Liczba Transakcji` DESC
LIMIT 10;
 
-- 8. Produkty o cenie jednostkowej wyższej niż średnia cena w ich kraju sprzedaży (Podzapytanie skorelowane)
SELECT 
    t.id_transakcji AS 'ID',
    kr.nazwa_kraju AS 'Kraj',
    t.kod_produktu AS 'Kod',
    p.opis_produktu AS 'Produkt',
    t.cena_jednostkowa AS 'Cena'
FROM transakcje t
JOIN produkty p ON t.kod_produktu = p.kod_produktu
JOIN klienci kl ON t.id_klienta = kl.id_klienta
JOIN kraje kr ON kl.id_kraju = kr.id_kraju
WHERE t.cena_jednostkowa > (
    SELECT AVG(t2.cena_jednostkowa)
    FROM transakcje t2
    JOIN klienci kl2 ON t2.id_klienta = kl2.id_klienta
    WHERE kl2.id_kraju = kl.id_kraju
)
LIMIT 15;
 
-- 9. Produkty widmo - dodane do bazy, ale nigdy niesprzedane (LEFT JOIN z filtrem NULL)
SELECT 
    p.kod_produktu AS 'Niekupowany Kod',
    p.opis_produktu AS 'Nazwa Artykulu'
FROM produkty p
LEFT JOIN transakcje t ON p.kod_produktu = t.kod_produktu
WHERE t.kod_produktu IS NULL;
 
-- 10. Analiza rozpiętości cenowej – produkty o największej fluktuacji ceny (Różnica Max i Min)
SELECT
    t.kod_produktu AS 'Kod Produktu',
    p.opis_produktu AS 'Produkt',
    MIN(t.cena_jednostkowa) AS 'Cena Minimalna',
    MAX(t.cena_jednostkowa) AS 'Cena Maksymalna',
    ROUND(MAX(t.cena_jednostkowa) - MIN(t.cena_jednostkowa), 2) AS 'Roznica Cenowa'
FROM transakcje t
JOIN produkty p ON t.kod_produktu = p.kod_produktu
WHERE p.opis_produktu NOT IN ('?', 'Brak opisu')
  AND t.cena_jednostkowa > 0.00                 
GROUP BY t.kod_produktu, p.opis_produktu
HAVING `Roznica Cenowa` > 0
ORDER BY `Roznica Cenowa` DESC
LIMIT 10;
 
-- 11. TOP 10 Najbardziej dochodowych Klientów (Klienci VIP)
SELECT 
    kl.id_klienta AS 'ID Klienta',
    kr.nazwa_kraju AS 'Kraj Pochodzenia',
    COUNT(DISTINCT t.numer_faktury) AS 'Liczba Zakupow',
    SUM(ROUND(t.ilosc * t.cena_jednostkowa, 2)) AS 'Wydana Kwota'
FROM transakcje t
JOIN klienci kl ON t.id_klienta = kl.id_klienta
JOIN kraje kr ON kl.id_kraju = kr.id_kraju
WHERE t.id_statusu = 1
GROUP BY kl.id_klienta, kr.nazwa_kraju
ORDER BY SUM(t.ilosc * t.cena_jednostkowa) DESC
LIMIT 10;
 
-- 12. Klienci, którzy zrobili zakupy powyżej średniej wartości zakupów wszystkich klientów
SELECT 
    t.id_klienta AS 'ID Klienta',
    SUM(ROUND(t.ilosc * t.cena_jednostkowa, 2)) AS 'Suma Wydatkow Klienta'
FROM transakcje t
WHERE t.id_statusu = 1
GROUP BY t.id_klienta
HAVING SUM(t.ilosc * t.cena_jednostkowa) > (
    SELECT AVG(suma_wydatkow)
    FROM (
        SELECT SUM(ilosc * cena_jednostkowa) AS suma_wydatkow
        FROM transakcje
        WHERE id_statusu = 1
        GROUP BY id_klienta
    ) AS SredniaTabela
)
ORDER BY `Suma Wydatkow Klienta` DESC;
 
-- 13. Liczba unikalnych klientów przypadająca na każdy kraj (Gdzie mamy największy rynek zbytu?)
SELECT 
    kr.nazwa_kraju AS 'Nazwa Kraju',
    COUNT(kl.id_klienta) AS 'Zarejestrowani Klienci',
    COUNT(DISTINCT t.id_klienta) AS 'Klienci Ktorzy Kupili Cokolwiek'
FROM kraje kr
LEFT JOIN klienci kl ON kr.id_kraju = kl.id_kraju
LEFT JOIN transakcje t ON kl.id_klienta = t.id_klienta
GROUP BY kr.nazwa_kraju
ORDER BY `Zarejestrowani Klienci` DESC;
 
-- 14. Klienci, którzy generują najwięcej zwrotów/anulowań (id_statusu = 2 to zwrot)
SELECT 
    IFNULL(t.id_klienta, 'Brak ID') AS 'ID Klienta',
    IFNULL(kr.nazwa_kraju, 'Nieznany Kraj') AS 'Kraj',
    COUNT(DISTINCT t.numer_faktury) AS 'Liczba Anulowanych Faktur',
    ABS(SUM(t.ilosc)) AS 'Zwrocone Sztuki Artykulow'
FROM transakcje t
LEFT JOIN klienci kl ON t.id_klienta = kl.id_klienta
LEFT JOIN kraje kr ON kl.id_kraju = kr.id_kraju
WHERE t.id_statusu = 2
GROUP BY t.id_klienta, kr.nazwa_kraju
ORDER BY `Liczba Anulowanych Faktur` DESC
LIMIT 5;

-- 15. Klienci jednorazowi (Kupili tylko raz i nie wrócili)
SELECT 
    t.id_klienta AS 'ID Jednorazowego Klienta',
    COUNT(DISTINCT t.numer_faktury) AS 'Liczba Faktur w Historii'
FROM transakcje t
WHERE t.id_klienta IS NOT NULL
GROUP BY t.id_klienta
HAVING `Liczba Faktur w Historii` = 1;
 
-- 16. Porównanie zamówień zrealizowanych vs zwróconych globalnie (Zliczanie warunkowe)
SELECT 
    sz.nazwa_statusu AS 'Status Transakcji',
    COUNT(DISTINCT t.numer_faktury) AS 'Liczba Zamowien',
    COUNT(t.id_transakcji) AS 'Liczba Pozycji na Fakturach',
    SUM(t.ilosc) AS 'Laczny Wolumen Produktow'
FROM transakcje t
JOIN statusy_zamowien sz ON t.id_statusu = sz.id_statusu
GROUP BY sz.id_statusu, sz.nazwa_statusu;
 
-- 17. Średnia wielkość zamówienia (liczba sztuk w jednej pozycji) wg lat
SELECT 
    YEAR(t.data_transakcji) AS 'Rok',
    ROUND(AVG(t.ilosc), 2) AS 'Srednia Ilosc Sztuk w Linii Faktury'
FROM transakcje t
WHERE t.data_transakcji IS NOT NULL 
  AND t.data_transakcji != '0000-00-00'
GROUP BY YEAR(t.data_transakcji)
ORDER BY Rok ASC;
 
-- 18. Identyfikacja transakcji nietypowych/hurtowych (Powyżej 500 sztuk w jednej pozycji)
SELECT 
    t.numer_faktury AS 'Numer Faktury',
    t.data_transakcji AS 'Data',
    p.opis_produktu AS 'Produkt',
    t.ilosc AS 'Ekstremalna Ilosc Sztuk',
    t.cena_jednostkowa AS 'Cena Za Sztuke'
FROM transakcje t
JOIN produkty p ON t.kod_produktu = p.kod_produktu
WHERE t.ilosc > 500 
  AND t.id_statusu = 1
ORDER BY t.ilosc DESC;
 
-- 19. Miesiąc o najwyższej sprzedaży w historii (Najlepszy finansowo okres)
SELECT 
    YEAR(t.data_transakcji) AS 'Rok',
    MONTH(t.data_transakcji) AS 'Miesiac',
    SUM(ROUND(t.ilosc * t.cena_jednostkowa, 2)) AS 'Rekordowy Przychod'
FROM transakcje t
WHERE t.id_statusu = 1
  AND t.data_transakcji IS NOT NULL 
  AND t.data_transakcji != '0000-00-00'
GROUP BY YEAR(t.data_transakcji), MONTH(t.data_transakcji)
ORDER BY `Rekordowy Przychod` DESC
LIMIT 1;
 
-- 20. Kraje z najwyższym odsetkiem zwrotów (Wskaźnik awaryjności logistycznej)
SELECT 
    IFNULL(kr.nazwa_kraju, 'Nieokreslony Kraj') AS 'Kraj',
    COUNT(CASE WHEN t.id_statusu = 2 THEN 1 END) AS 'Liczba Zwrotow',
    COUNT(t.id_transakcji) AS 'Wszystkie Pozycje',
    ROUND((COUNT(CASE WHEN t.id_statusu = 2 THEN 1 END) / COUNT(t.id_transakcji)) * 100, 2) AS 'Procent Zwrotow %'
FROM transakcje t
LEFT JOIN klienci kl ON t.id_klienta = kl.id_klienta
LEFT JOIN kraje kr ON kl.id_kraju = kr.id_kraju
GROUP BY kr.nazwa_kraju
ORDER BY `Procent Zwrotow %` DESC;

-- Zapytanie dodatkowe: Ranking przychodów per kraj w samym roku 2020
SELECT 
    kr.nazwa_kraju AS 'Kraj',
    COUNT(DISTINCT t.numer_faktury) AS 'Liczba Faktur',
    SUM(ROUND(t.ilosc * t.cena_jednostkowa, 2)) AS 'Przychod w 2020 Roku'
FROM transakcje t
JOIN klienci kl ON t.id_klienta = kl.id_klienta
JOIN kraje kr ON kl.id_kraju = kr.id_kraju
WHERE t.id_statusu = 1
  AND YEAR(t.data_transakcji) = 2020
GROUP BY kr.nazwa_kraju
ORDER BY SUM(t.ilosc * t.cena_jednostkowa) DESC;
