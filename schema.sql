-- DATABASE SCHEMA

-- === RESET ===
DROP VIEW IF EXISTS "current_assets";
DROP VIEW IF EXISTS "latest_market_prices";
DROP VIEW IF EXISTS "unrealized_profits";
DROP VIEW IF EXISTS "realized_profits";
DROP VIEW IF EXISTS "portfolio_overview";
DROP VIEW IF EXISTS "dividends_received";
DROP VIEW IF EXISTS "full_portfolio_summary";
DROP VIEW IF EXISTS "transactions_history";

DROP INDEX IF EXISTS "idx_transactions_user_id";
DROP INDEX IF EXISTS "idx_transactions_asset_id";
DROP INDEX IF EXISTS "idx_dividends_user_id";
DROP INDEX IF EXISTS "idx_dividends_asset_id";
DROP INDEX IF EXISTS "idx_market_prices_asset_id";
DROP INDEX IF EXISTS "idx_users_username";
DROP INDEX IF EXISTS "idx_assets_ticker";
DROP INDEX IF EXISTS "idx_transactions_user_asset_datetime";

DROP TABLE IF EXISTS "market_prices";
DROP TABLE IF EXISTS "cash_movements";
DROP TABLE IF EXISTS "dividends";
DROP TABLE IF EXISTS "transactions";
DROP TABLE IF EXISTS "assets";
DROP TABLE IF EXISTS "users";

-- === TABLE CREATION ===
CREATE TABLE "users" (
    "id" INTEGER,
    "username" TEXT NOT NULL UNIQUE,
    "password" TEXT NOT NULL,
    "names" TEXT NOT NULL,
    "surnames" TEXT NOT NULL,
    "balance" REAL NOT NULL DEFAULT 0 CHECK("balance" >= 0),
    PRIMARY KEY("id")
);

CREATE TABLE "cash_movements" (
    "id" INTEGER,
    "user_id" INTEGER,
    "type" TEXT NOT NULL CHECK("type" IN ('deposit', 'withdrawal')),
    "datetime" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "amount" REAL NOT NULL CHECK("amount" >= 0),
    PRIMARY KEY("id"),
    FOREIGN KEY("user_id") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE TABLE "assets" (
    "id" INTEGER,
    "type" TEXT NOT NULL,
    "name" TEXT NOT NULL UNIQUE,
    "ticker" TEXT NOT NULL UNIQUE,
    "sector" TEXT,
    PRIMARY KEY("id")
);

CREATE TABLE "transactions" (
    "id" INTEGER,
    "user_id" INTEGER,
    "asset_id" INTEGER,
    "datetime" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "type" TEXT NOT NULL CHECK("type" IN ('buy', 'sell')),
    "quantity" REAL NOT NULL,
    "price" REAL NOT NULL CHECK("price" >= 0),
    PRIMARY KEY("id"),
    FOREIGN KEY("user_id") REFERENCES "users"("id") ON DELETE CASCADE,
    FOREIGN KEY("asset_id") REFERENCES "assets"("id")
);

CREATE TABLE "dividends" (
    "id" INTEGER,
    "user_id" INTEGER,
    "asset_id" INTEGER,
    "amount_per_share" REAL NOT NULL CHECK("amount_per_share" >= 0),
    "ex_date" DATE NOT NULL,
    "datetime" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY("id"),
    FOREIGN KEY("user_id") REFERENCES "users"("id") ON DELETE CASCADE,
    FOREIGN KEY("asset_id") REFERENCES "assets"("id")
);

CREATE TABLE "market_prices" (
    "asset_id" INTEGER,
    "price" REAL NOT NULL CHECK("price" >= 0),
    "datetime" DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY("asset_id", "datetime"),
    FOREIGN KEY("asset_id") REFERENCES "assets"("id")
);

-- === IMPORT DATA ===
.import --csv --skip 1 data/users.csv users
.import --csv --skip 1 data/assets.csv assets
.import --csv --skip 1 data/transactions.csv transactions
.import --csv --skip 1 data/cash_movements.csv cash_movements
.import --csv --skip 1 data/dividends.csv dividends
.import --csv --skip 1 data/market_prices.csv market_prices

-- === VIEWS ===
-- See current assets
CREATE VIEW "current_assets"
AS SELECT
    *,
    ROUND("net_invested" / NULLIF("total_quantity", 0), 2) AS "average_price"
FROM (
    SELECT
        "username",
        "ticker",
        SUM(
            CASE
                WHEN "transactions"."type" = 'buy' THEN "transactions"."quantity"
                WHEN "transactions"."type" = 'sell' THEN - "transactions"."quantity"
            ELSE 0
            END
        ) AS "total_quantity",
        ROUND(SUM(
            CASE
                WHEN "transactions"."type" = 'buy' THEN "transactions"."quantity" * "transactions"."price"
            ELSE 0
            END
        ), 2) AS "gross_invested",
        ROUND(SUM(
            CASE
                WHEN "transactions"."type" = 'buy' THEN "transactions"."quantity" * "transactions"."price"
                WHEN "transactions"."type" = 'sell' THEN - "transactions"."quantity" * "transactions"."price"
            ELSE 0
            END
        ), 2) AS "net_invested"
    FROM
        "users"
    JOIN
        "transactions"
    ON
        "users"."id" = "transactions"."user_id"
    JOIN
        "assets"
    ON
        "transactions"."asset_id" = "assets"."id"
    GROUP BY
        "username",
        "ticker"
    HAVING
        "total_quantity" > 0
    );

-- See latest market prices
CREATE VIEW "latest_market_prices"
AS SELECT
    "assets"."ticker" AS "ticker",
    "market_prices"."price" AS "price",
    MAX("datetime") AS "last_date"
FROM
    "market_prices"
JOIN
    "assets"
ON
    "market_prices"."asset_id" = "assets"."id"
GROUP BY
    "assets"."ticker"
HAVING
    "market_prices"."datetime" = "last_date"
ORDER BY
    "assets"."ticker";

-- See profits not realized yet
CREATE VIEW "unrealized_profits"
AS SELECT
    "current_assets"."username" AS "username",
    "current_assets"."ticker",
    "current_assets"."total_quantity",
    "current_assets"."average_price",
    "latest_market_prices"."price" AS "last_market_price",
    ROUND(("latest_market_prices"."price" - "average_price") * "total_quantity", 2) AS "unrealized_profit"
FROM
    "current_assets"
JOIN
    "latest_market_prices"
ON
    "current_assets"."ticker" = "latest_market_prices"."ticker";

-- See realized profits
CREATE VIEW "realized_profits"
AS SELECT
    "users"."username" AS "username",
    "assets"."ticker" AS "ticker",
    ROUND(SUM(
        CASE
            WHEN "t"."type" = 'sell'
            THEN ("t"."price" -
                (SELECT SUM("buy"."quantity" * "buy"."price") / NULLIF(SUM("buy"."quantity"), 0)
                FROM
                    "transactions" AS "buy"
                WHERE
                    "buy"."type" = 'buy'
                    AND "buy"."user_id" = "t"."user_id"
                    AND "buy"."asset_id" = "t"."asset_id"
                    AND "buy"."datetime" <= "t"."datetime"
                ))
                * "t"."quantity"
        ELSE 0
        END
    ), 2) AS "realized_profit"
FROM
    "transactions" AS "t"
JOIN
    "assets"
ON
    "t"."asset_id" = "assets"."id"
JOIN
    "users"
ON
    "t"."user_id" = "users"."id"
WHERE
    "t"."type" = 'sell'
GROUP BY
    "users"."username",
    "assets"."ticker";

-- See received dividends
CREATE VIEW "dividends_received"
AS SELECT
    "users"."username" AS "username",
    "assets"."ticker",
    ROUND(SUM("dividends"."amount_per_share" * (
        SELECT COALESCE(SUM(
            CASE
                WHEN "transactions"."type" = 'buy' AND "transactions"."datetime" <= "dividends"."ex_date"
                THEN "transactions"."quantity"
                WHEN "transactions"."type" = 'sell' AND "transactions"."datetime" <= "dividends"."ex_date"
                THEN - "transactions"."quantity"
            ELSE 0
            END
        ), 0)
        FROM
            "transactions"
        WHERE
            "transactions"."user_id" = "dividends"."user_id"
            AND
            "transactions"."asset_id" = "dividends"."asset_id")
        ), 2) AS "total_dividend"
FROM
    "dividends"
JOIN
    "users"
ON
    "dividends"."user_id" = "users"."id"
JOIN
    "assets"
ON
    "dividends"."asset_id" = "assets"."id"
GROUP BY
    "users"."username",
    "assets"."ticker";

-- See transaction history of a user
CREATE VIEW "transactions_history"
AS SELECT
    "cash_movements"."id",
    "username",
    NULL AS "ticker",
    "type",
    "datetime",
    NULL AS "quantity",
    NULL AS "price",
    "amount"
FROM
    "cash_movements"
JOIN
    "users"
ON
    "cash_movements"."user_id" = "users"."id"

UNION ALL

SELECT
    "transactions"."id",
    "username",
    "assets"."ticker",
    "transactions"."type",
    "datetime",
    "quantity",
    "price",
    "quantity" * "price" AS "amount"
FROM
    "transactions"
JOIN
    "users"
ON
    "transactions"."user_id" = "users"."id"
JOIN
    "assets"
ON
    "transactions"."asset_id" = "assets"."id"

UNION ALL

SELECT
    "dividends"."id",
    "users"."username",
    "assets"."ticker",
    'dividend pay',
    "dividends"."datetime",
    NULL AS "quantity",
    NULL AS "price",
    (SELECT
        SUM(
            CASE
                WHEN "transactions"."type" = 'buy' AND "transactions"."datetime" <= "dividends"."ex_date"
                THEN "transactions"."quantity"
                WHEN "transactions"."type" = 'sell' AND "transactions"."datetime" <= "dividends"."ex_date"
                THEN - "transactions"."quantity"
            ELSE 0
            END) * "dividends"."amount_per_share" AS "amount"
        FROM
            "transactions"
    )
FROM
    "dividends"
JOIN
    "users"
ON
    "dividends"."user_id" = "users"."id"
JOIN
    "assets"
ON
    "dividends"."asset_id" = "assets"."id"
ORDER BY
    "datetime" DESC;


-- See the current portfolio of a user
CREATE VIEW "portfolio_overview"
AS SELECT
    *,
    ROUND("realized_profit" + "unrealized_profit" + "dividend_profit", 2) AS "total_profit",
    ROUND(100.0 * ("realized_profit" + "unrealized_profit" + "dividend_profit") /
        NULLIF("total_cost", 0), 2) AS "profit_percent",
    ROUND(100.0 * "current_value" /
        NULLIF(
                (SELECT
                    SUM("ca"."total_quantity" * "lmp"."price")
                FROM
                    "current_assets" AS "ca"
                JOIN
                    "latest_market_prices" AS "lmp"
                ON
                    "ca"."ticker" = "lmp"."ticker"
                WHERE
                    "ca"."username" = "po_base"."username")
                , 0), 2) AS "asset_allocation_percent"
FROM (
    SELECT
        "current_assets"."username" AS "username",
        "current_assets"."ticker" AS "ticker",
        "current_assets"."total_quantity" AS "total_quantity",
        "current_assets"."average_price" AS "average_price",
        "latest_market_prices"."price" AS "market_price",
        COALESCE(ROUND("current_assets"."total_quantity" * "latest_market_prices"."price", 2), 0) AS "current_value",
        COALESCE(ROUND("current_assets"."total_quantity" * "current_assets"."average_price", 2), 0) AS "total_cost",
        COALESCE("realized_profit", 0) AS "realized_profit",
        COALESCE("unrealized_profit", 0) AS "unrealized_profit",
        COALESCE("total_dividend", 0) AS "dividend_profit"

    FROM
        "current_assets"
    JOIN
        "latest_market_prices"
    ON
        "current_assets"."ticker" = "latest_market_prices"."ticker"
    LEFT JOIN
        "dividends_received"
    ON
        "current_assets"."ticker" = "dividends_received"."ticker"
        AND
        "current_assets"."username" = "dividends_received"."username"
    LEFT JOIN
        "realized_profits"
    ON
        "realized_profits"."ticker" = "current_assets"."ticker"
        AND
        "realized_profits"."username" = "current_assets"."username"
    LEFT JOIN
        "unrealized_profits"
    ON
        "unrealized_profits"."ticker" = "current_assets"."ticker"
        AND
        "unrealized_profits"."username" = "current_assets"."username"
    WHERE "current_assets"."total_quantity" > 0
    ) AS "po_base"
GROUP BY
    "username",
    "ticker";

-- Summary of stats
CREATE VIEW "full_portfolio_summary"
AS SELECT
    "users"."username" AS "username",
    "users"."balance" AS "balance",
    ROUND(SUM("current_value"), 2) AS "total_value",
    "users"."balance" + ROUND(SUM("current_value"), 2) AS "net_worth",
    ROUND(SUM("total_cost"), 2) AS "total_cost",
    ROUND(SUM("realized_profit"), 2) AS "realized_profit",
    ROUND(SUM("unrealized_profit"), 2) AS "total_unrealized_profit",
    ROUND(SUM("dividend_profit"), 2) AS "total_dividend_profit",
    ROUND(SUM("total_profit"), 2) AS "total_profit",
    ROUND(100.0 * SUM("total_profit") /
        NULLIF(SUM("total_cost"), 0), 2) AS "profit_percent"
FROM
    "portfolio_overview"
JOIN
    "users"
ON
    "portfolio_overview"."username" = "users"."username"
GROUP BY
    "users"."username";

-- === TRIGGERS ===
-- Check the amount of stocks before selling
CREATE TRIGGER "check_quantity_before_selling"
BEFORE INSERT ON
    "transactions"
WHEN
    NEW."type" = "sell"
BEGIN
    SELECT CASE
        WHEN (
            SELECT
                "total_quantity"
            FROM
                "current_assets"
            WHERE
                "username" = (
                    SELECT "id" FROM "users"
                    WHERE
                        "id" = NEW."user_id")
                AND
                "ticker" = (
                    SELECT "ticker" FROM "assets"
                    WHERE
                        "id" = NEW."asset_id"
                )
            ) < NEW."quantity"
        THEN
            RAISE(ABORT, "Not enough assets to sell")
        END;
END;

-- Edit ticker of assets is not allowed if referenced
CREATE TRIGGER "prevent_edit_ticker"
BEFORE UPDATE OF ticker ON assets
WHEN EXISTS (
    SELECT 1 FROM transactions WHERE asset_id = OLD.id
    UNION
    SELECT 1 FROM dividends WHERE asset_id = OLD.id
    UNION
    SELECT 1 FROM market_prices WHERE asset_id = OLD.id
)
BEGIN
    SELECT RAISE(ABORT, 'Cannot modify ticker of an asset already in use');
END;

-- Updates on transactions are not allowed
CREATE TRIGGER "prevent_update_transactions"
BEFORE UPDATE ON "transactions"
BEGIN
    SELECT RAISE(ABORT, 'Updates to transactions are not allowed');
END;

-- Deletitions on transactions are not allowed
CREATE TRIGGER "prevent_delete_transactions"
BEFORE DELETE ON "transactions"
BEGIN
    SELECT RAISE(ABORT, 'Deletions of transactions are not allowed');
END;

-- Updates on dividends are not allowed
CREATE TRIGGER "prevent_update_dividends"
BEFORE UPDATE ON "dividends"
BEGIN
    SELECT RAISE(ABORT, 'Updates to dividends are not allowed');
END;

-- Deletitions on dividends are not allowed
CREATE TRIGGER "prevent_delete_dividends"
BEFORE DELETE ON "dividends"
BEGIN
    SELECT RAISE(ABORT, 'Deletions of dividends are not allowed');
END;

-- Updates on market prices are not allowed
CREATE TRIGGER "prevent_update_market_prices"
BEFORE UPDATE ON "market_prices"
BEGIN
    SELECT RAISE(ABORT, 'Updates to market_prices are not allowed');
END;

-- Deletitions on market_prices are not allowed
CREATE TRIGGER "prevent_delete_market_prices"
BEFORE DELETE ON "market_prices"
BEGIN
    SELECT RAISE(ABORT, 'Deletions of market_prices are not allowed');
END;

-- Updates on cash movements table are not allowed
CREATE TRIGGER "prevent_update_cash_movements"
BEFORE UPDATE ON "cash_movements"
BEGIN
    SELECT RAISE(ABORT, 'Updates to cash_movements are not allowed');
END;

-- Deletitions on cash movements table are not allowed
CREATE TRIGGER "prevent_delete_cash_movements"
BEFORE DELETE ON "cash_movements"
BEGIN
    SELECT RAISE(ABORT, 'Deletions of cash_movements are not allowed');
END;

-- === INDEXES ===
CREATE INDEX "idx_transactions_user_id" ON "transactions"("user_id");
CREATE INDEX "idx_transactions_asset_id" ON "transactions"("asset_id");
CREATE INDEX "idx_transactions_user_asset" ON "transactions"("user_id", "asset_id");

CREATE INDEX "idx_dividends_user_id" ON dividends("user_id");
CREATE INDEX "idx_dividends_asset_id" ON dividends("asset_id");

CREATE INDEX "idx_market_prices_asset_id" ON "market_prices"("asset_id");

CREATE INDEX "idx_users_username" ON "users"("username");
CREATE INDEX "idx_assets_ticker" ON "assets"("ticker");

CREATE INDEX "idx_transactions_user_asset_datetime" ON "transactions"("user_id", "asset_id","datetime");
