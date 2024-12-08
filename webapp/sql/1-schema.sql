SET CHARACTER_SET_CLIENT = utf8mb4;
SET CHARACTER_SET_CONNECTION = utf8mb4;

USE isuride;

DROP TABLE IF EXISTS settings;
CREATE TABLE settings
(
  name  VARCHAR(30) NOT NULL COMMENT '設定名',
  value TEXT        NOT NULL COMMENT '設定値',
  PRIMARY KEY (name)
)
  COMMENT = 'システム設定テーブル';

DROP TABLE IF EXISTS chair_models;
CREATE TABLE chair_models
(
  name  VARCHAR(50) NOT NULL COMMENT '椅子モデル名',
  speed INTEGER     NOT NULL COMMENT '移動速度',
  PRIMARY KEY (name)
)
  COMMENT = '椅子モデルテーブル';

DROP TABLE IF EXISTS chairs;
CREATE TABLE chairs
(
  id           VARCHAR(26)  NOT NULL COMMENT '椅子ID',
  owner_id     VARCHAR(26)  NOT NULL COMMENT 'オーナーID',
  name         VARCHAR(30)  NOT NULL COMMENT '椅子の名前',
  model        TEXT         NOT NULL COMMENT '椅子のモデル',
  is_active    TINYINT(1)   NOT NULL COMMENT '配椅子受付中かどうか',
  access_token VARCHAR(255) NOT NULL COMMENT 'アクセストークン',
  created_at   DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '登録日時',
  updated_at   DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新日時',
  PRIMARY KEY (id)
)
  COMMENT = '椅子情報テーブル';

ALTER TABLE chairs
ADD COLUMN latitude INTEGER COMMENT '経度' AFTER is_active,
ADD COLUMN longitude INTEGER COMMENT '緯度' AFTER latitude,
ADD COLUMN location_updated_at DATETIME(6) COMMENT '位置情報の更新日時' AFTER longitude;
-- UPDATE chairs c
-- JOIN (
--     SELECT 
--         cl.chair_id,
--         cl.latitude,
--         cl.longitude,
--         cl.created_at AS location_updated_at
--     FROM chair_locations cl
--     INNER JOIN (
--         SELECT chair_id, MAX(created_at) AS max_created_at
--         FROM chair_locations
--         GROUP BY chair_id
--     ) latest
--     ON cl.chair_id = latest.chair_id AND cl.created_at = latest.max_created_at
-- ) latest_location
-- ON c.id = latest_location.chair_id
-- SET 
--     c.latitude = latest_location.latitude,
--     c.longitude = latest_location.longitude,
--     c.location_updated_at = latest_location.location_updated_at;
ALTER TABLE chairs
ADD COLUMN total_distance INTEGER NOT NULL DEFAULT 0 COMMENT '総距離' AFTER longitude;
-- UPDATE chairs c
-- LEFT JOIN (
--     SELECT chair_id,
--            SUM(IFNULL(distance, 0)) AS total_distance
--     FROM (
--         SELECT chair_id,
--                ABS(latitude - LAG(latitude) OVER (PARTITION BY chair_id ORDER BY created_at)) +
--                ABS(longitude - LAG(longitude) OVER (PARTITION BY chair_id ORDER BY created_at)) AS distance
--         FROM chair_locations
--     ) tmp
--     GROUP BY chair_id
-- ) distance_table
-- ON c.id = distance_table.chair_id
-- SET c.total_distance = IFNULL(distance_table.total_distance, 0);
ALTER TABLE chairs
ADD COLUMN is_free TINYINT(1) NOT NULL DEFAULT 1 COMMENT 'マッチ中かどうか' AFTER is_active;
-- UPDATE chairs c
-- LEFT JOIN (
--     SELECT
--         r.chair_id,
--         MAX(CASE WHEN rs.status = 'COMPLETED' THEN 1 ELSE 0 END) AS has_completed_ride
--     FROM rides r
--     LEFT JOIN ride_statuses rs ON r.id = rs.ride_id
--     GROUP BY r.chair_id
-- ) ride_data ON c.id = ride_data.chair_id
-- SET c.is_free = CASE
--     WHEN ride_data.chair_id IS NULL OR ride_data.has_completed_ride = 1 THEN 1
--     ELSE 0
-- END;
ALTER TABLE chairs
ADD COLUMN is_matchable TINYINT(1) AS (is_active AND is_free) STORED NOT NULL COMMENT 'マッチ可能かどうか';

CREATE INDEX idx_chairs_created_at ON chairs (created_at);

CREATE INDEX idx_chairs_owner_id_created_at ON chairs (owner_id, created_at DESC);

CREATE INDEX idx_is_matchable ON chairs (is_matchable);

DROP TABLE IF EXISTS chair_locations;
CREATE TABLE chair_locations
(
  id         VARCHAR(26) NOT NULL,
  chair_id   VARCHAR(26) NOT NULL COMMENT '椅子ID',
  latitude   INTEGER     NOT NULL COMMENT '経度',
  longitude  INTEGER     NOT NULL COMMENT '緯度',
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '登録日時',
  PRIMARY KEY (id)
)
  COMMENT = '椅子の現在位置情報テーブル';

DROP TABLE IF EXISTS users;
CREATE TABLE users
(
  id              VARCHAR(26)  NOT NULL COMMENT 'ユーザーID',
  username        VARCHAR(30)  NOT NULL COMMENT 'ユーザー名',
  firstname       VARCHAR(30)  NOT NULL COMMENT '本名(名前)',
  lastname        VARCHAR(30)  NOT NULL COMMENT '本名(名字)',
  date_of_birth   VARCHAR(30)  NOT NULL COMMENT '生年月日',
  access_token    VARCHAR(255) NOT NULL COMMENT 'アクセストークン',
  invitation_code VARCHAR(30)  NOT NULL COMMENT '招待トークン',
  created_at      DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '登録日時',
  updated_at      DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新日時',
  PRIMARY KEY (id),
  UNIQUE (username),
  UNIQUE (access_token),
  UNIQUE (invitation_code)
)
  COMMENT = '利用者情報テーブル';

DROP TABLE IF EXISTS payment_tokens;
CREATE TABLE payment_tokens
(
  user_id    VARCHAR(26)  NOT NULL COMMENT 'ユーザーID',
  token      VARCHAR(255) NOT NULL COMMENT '決済トークン',
  created_at DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '登録日時',
  PRIMARY KEY (user_id)
)
  COMMENT = '決済トークンテーブル';

DROP TABLE IF EXISTS rides;
CREATE TABLE rides
(
  id                    VARCHAR(26) NOT NULL COMMENT 'ライドID',
  user_id               VARCHAR(26) NOT NULL COMMENT 'ユーザーID',
  chair_id              VARCHAR(26) NULL     COMMENT '割り当てられた椅子ID',
  pickup_latitude       INTEGER     NOT NULL COMMENT '配車位置(経度)',
  pickup_longitude      INTEGER     NOT NULL COMMENT '配車位置(緯度)',
  destination_latitude  INTEGER     NOT NULL COMMENT '目的地(経度)',
  destination_longitude INTEGER     NOT NULL COMMENT '目的地(緯度)',
  evaluation            INTEGER     NULL     COMMENT '評価',
  created_at            DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '要求日時',
  updated_at            DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '状態更新日時',
  PRIMARY KEY (id)
)
  COMMENT = 'ライド情報テーブル';
CREATE INDEX idx_rides_chair_id_created_at ON rides (chair_id, created_at);

DROP TABLE IF EXISTS ride_statuses;
CREATE TABLE ride_statuses
(
  id              VARCHAR(26)                                                                NOT NULL,
  ride_id VARCHAR(26)                                                                        NOT NULL COMMENT 'ライドID',
  status          ENUM ('MATCHING', 'ENROUTE', 'PICKUP', 'CARRYING', 'ARRIVED', 'COMPLETED') NOT NULL COMMENT '状態',
  created_at      DATETIME(6)                                                                NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '状態変更日時',
  app_sent_at     DATETIME(6)                                                                NULL COMMENT 'ユーザーへの状態通知日時',
  chair_sent_at   DATETIME(6)                                                                NULL COMMENT '椅子への状態通知日時',
  PRIMARY KEY (id)
)
  COMMENT = 'ライドステータスの変更履歴テーブル';
CREATE INDEX idx_ride_statuses_ride_id_created_at ON rides (ride_id, created_at DESC);

DROP TABLE IF EXISTS owners;
CREATE TABLE owners
(
  id                   VARCHAR(26)  NOT NULL COMMENT 'オーナーID',
  name                 VARCHAR(30)  NOT NULL COMMENT 'オーナー名',
  access_token         VARCHAR(255) NOT NULL COMMENT 'アクセストークン',
  chair_register_token VARCHAR(255) NOT NULL COMMENT '椅子登録トークン',
  created_at           DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '登録日時',
  updated_at           DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6) COMMENT '更新日時',
  PRIMARY KEY (id),
  UNIQUE (name),
  UNIQUE (access_token),
  UNIQUE (chair_register_token)
)
  COMMENT = '椅子のオーナー情報テーブル';

DROP TABLE IF EXISTS coupons;
CREATE TABLE coupons
(
  user_id    VARCHAR(26)  NOT NULL COMMENT '所有しているユーザーのID',
  code       VARCHAR(255) NOT NULL COMMENT 'クーポンコード',
  discount   INTEGER      NOT NULL COMMENT '割引額',
  created_at DATETIME(6)  NOT NULL DEFAULT CURRENT_TIMESTAMP(6) COMMENT '付与日時',
  used_by    VARCHAR(26)  NULL COMMENT 'クーポンが適用されたライドのID',
  PRIMARY KEY (user_id, code)
)
  COMMENT 'クーポンテーブル';
