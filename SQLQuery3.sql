CREATE DATABASE AirbnbDB;

USE AirbnbDB;
GO

IF OBJECT_ID('dbo.dim_city', 'U') IS NOT NULL
    DROP TABLE dbo.dim_city;

CREATE TABLE dbo.dim_city (
    city_key INT IDENTITY(1,1) PRIMARY KEY,
    city_name VARCHAR(50) NOT NULL UNIQUE
);
GO

INSERT INTO dbo.dim_city (city_name)
SELECT DISTINCT LTRIM(RTRIM(city))
FROM dbo.airbnb_combined
WHERE city IS NOT NULL;
GO

IF OBJECT_ID('dbo.dim_room_type', 'U') IS NOT NULL
    DROP TABLE dbo.dim_room_type;

CREATE TABLE dbo.dim_room_type (
    room_type_key INT IDENTITY(1,1) PRIMARY KEY,
    room_type VARCHAR(50) NOT NULL,
    is_shared BIT NOT NULL,
    is_private BIT NOT NULL
);
GO

INSERT INTO dbo.dim_room_type (room_type, is_shared, is_private)
SELECT DISTINCT
    LTRIM(RTRIM(room_type)),
    CASE WHEN LOWER(LTRIM(RTRIM(room_shared))) = 'true' THEN 1 ELSE 0 END,
    CASE WHEN LOWER(LTRIM(RTRIM(room_private))) = 'true' THEN 1 ELSE 0 END
FROM dbo.airbnb_combined
WHERE room_type IS NOT NULL;
GO

IF OBJECT_ID('dbo.dim_day_type', 'U') IS NOT NULL
    DROP TABLE dbo.dim_day_type;

CREATE TABLE dbo.dim_day_type (
    day_type_key INT IDENTITY(1,1) PRIMARY KEY,
    day_type VARCHAR(20) NOT NULL UNIQUE,
    is_weekend BIT NOT NULL
);
GO

INSERT INTO dbo.dim_day_type (day_type, is_weekend)
SELECT DISTINCT
    LTRIM(RTRIM(day_type)),
    CASE WHEN LOWER(LTRIM(RTRIM(day_type))) = 'weekend' THEN 1 ELSE 0 END
FROM dbo.airbnb_combined
WHERE day_type IS NOT NULL;
GO

IF OBJECT_ID('dbo.dim_host_profile', 'U') IS NOT NULL
    DROP TABLE dbo.dim_host_profile;

CREATE TABLE dbo.dim_host_profile (
    host_profile_key INT IDENTITY(1,1) PRIMARY KEY,
    is_superhost BIT NOT NULL,
    is_multi_listing BIT NOT NULL,
    is_business BIT NOT NULL
);
GO

INSERT INTO dbo.dim_host_profile (is_superhost, is_multi_listing, is_business)
SELECT DISTINCT
    CASE WHEN LOWER(LTRIM(RTRIM(host_is_superhost))) = 'true' THEN 1 ELSE 0 END,
    CASE WHEN LTRIM(RTRIM(multi)) = '1' THEN 1 ELSE 0 END,
    CASE WHEN LTRIM(RTRIM(biz)) = '1' THEN 1 ELSE 0 END
FROM dbo.airbnb_combined;
GO

IF OBJECT_ID('dbo.fact_listings', 'U') IS NOT NULL
    DROP TABLE dbo.fact_listings;

CREATE TABLE dbo.fact_listings (
    listing_key INT IDENTITY(1,1) PRIMARY KEY,
    city_key INT NOT NULL REFERENCES dbo.dim_city(city_key),
    room_type_key INT NOT NULL REFERENCES dbo.dim_room_type(room_type_key),
    day_type_key INT NOT NULL REFERENCES dbo.dim_day_type(day_type_key),
    host_profile_key INT NOT NULL REFERENCES dbo.dim_host_profile(host_profile_key),
    person_capacity FLOAT,
    bedrooms INT,
    price FLOAT,
    cleanliness_rating FLOAT,
    guest_satisfaction_overall FLOAT,
    dist_km FLOAT,
    metro_dist_km FLOAT,
    attr_index FLOAT,
    attr_index_norm FLOAT,
    rest_index FLOAT,
    rest_index_norm FLOAT,
    longitude FLOAT,
    latitude FLOAT
);
GO

INSERT INTO dbo.fact_listings (
    city_key,
    room_type_key,
    day_type_key,
    host_profile_key,
    person_capacity,
    bedrooms,
    price,
    cleanliness_rating,
    guest_satisfaction_overall,
    dist_km,
    metro_dist_km,
    attr_index,
    attr_index_norm,
    rest_index,
    rest_index_norm,
    longitude,
    latitude
)
SELECT
    c.city_key,
    rt.room_type_key,
    dt.day_type_key,
    hp.host_profile_key,
    TRY_CAST(s.person_capacity AS FLOAT),
    TRY_CAST(s.bedrooms AS INT),
    TRY_CAST(s.realSum AS FLOAT),
    TRY_CAST(s.cleanliness_rating AS FLOAT),
    TRY_CAST(s.guest_satisfaction_overall AS FLOAT),
    TRY_CAST(s.dist AS FLOAT),
    TRY_CAST(s.metro_dist AS FLOAT),
    TRY_CAST(s.attr_index AS FLOAT),
    TRY_CAST(s.attr_index_norm AS FLOAT),
    TRY_CAST(s.rest_index AS FLOAT),
    TRY_CAST(s.rest_index_norm AS FLOAT),
    TRY_CAST(s.lng AS FLOAT),
    TRY_CAST(s.lat AS FLOAT)
FROM dbo.airbnb_combined s
JOIN dbo.dim_city c
ON LTRIM(RTRIM(s.city)) = c.city_name
JOIN dbo.dim_room_type rt
ON LTRIM(RTRIM(s.room_type)) = rt.room_type
AND (CASE WHEN LOWER(LTRIM(RTRIM(s.room_shared))) = 'true' THEN 1 ELSE 0 END) = rt.is_shared
AND (CASE WHEN LOWER(LTRIM(RTRIM(s.room_private))) = 'true' THEN 1 ELSE 0 END) = rt.is_private
JOIN dbo.dim_day_type dt
ON LTRIM(RTRIM(s.day_type)) = dt.day_type
JOIN dbo.dim_host_profile hp
ON (CASE WHEN LOWER(LTRIM(RTRIM(s.host_is_superhost))) = 'true' THEN 1 ELSE 0 END) = hp.is_superhost
AND (CASE WHEN LTRIM(RTRIM(s.multi)) = '1' THEN 1 ELSE 0 END) = hp.is_multi_listing
AND (CASE WHEN LTRIM(RTRIM(s.biz)) = '1' THEN 1 ELSE 0 END) = hp.is_business;
GO

CREATE INDEX idx_fact_city
ON dbo.fact_listings(city_key);

CREATE INDEX idx_fact_room_type
ON dbo.fact_listings(room_type_key);

CREATE INDEX idx_fact_day_type
ON dbo.fact_listings(day_type_key);

CREATE INDEX idx_fact_host_profile
ON dbo.fact_listings(host_profile_key);
GO

SELECT 'airbnb_combined' AS tbl, COUNT(*) AS row_count
FROM dbo.airbnb_combined

UNION ALL

SELECT 'fact_listings', COUNT(*)
FROM dbo.fact_listings

UNION ALL

SELECT 'dim_city', COUNT(*)
FROM dbo.dim_city

UNION ALL

SELECT 'dim_room_type', COUNT(*)
FROM dbo.dim_room_type

UNION ALL

SELECT 'dim_day_type', COUNT(*)
FROM dbo.dim_day_type

UNION ALL

SELECT 'dim_host_profile', COUNT(*)
FROM dbo.dim_host_profile;

SELECT
    c.city_name,
    rt.room_type,
    ROUND(AVG(f.price), 2) AS avg_price,
    COUNT(*) AS num_listings
FROM dbo.fact_listings f
JOIN dbo.dim_city c
ON f.city_key = c.city_key
JOIN dbo.dim_room_type rt
ON f.room_type_key = rt.room_type_key
JOIN dbo.dim_day_type dt
ON f.day_type_key = dt.day_type_key
WHERE dt.day_type = 'weekend'
GROUP BY
    c.city_name,
    rt.room_type
ORDER BY avg_price DESC;
GO