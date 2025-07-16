-- === TYPICAL QUERIES ===

-- Buy a stock
BEGIN TRANSACTION;
UPDATE
    "users"
SET
    "balance" = "balance" - 200
WHERE
    "username" = 'nicolas';

INSERT INTO "transactions" ("user_id", "asset_id", "datetime", "type", "quantity", "price")
SELECT
    "users"."id",
    "assets"."id",
    CURRENT_TIMESTAMP,
    'buy',
    1,
    200
FROM
    "users",
    "assets"
WHERE
    "users"."username" = 'nicolas'
    AND
    "assets"."ticker" = 'AAPL';
COMMIT;

-- Sell a stock
BEGIN TRANSACTION;
UPDATE
    "users"
SET
    "balance" = "balance" + 200
WHERE
    "username" = 'nicolas';

INSERT INTO "transactions" ("user_id", "asset_id", "datetime", "type", "quantity", "price")
SELECT
    "users"."id",
    "assets"."id",
    CURRENT_TIMESTAMP,
    'sell',
    1,
    200
FROM
    "users",
    "assets"
WHERE
    "users"."username" = 'nicolas'
    AND
    "assets"."ticker" = 'AAPL';
COMMIT;


-- Deposit 100 dollars
BEGIN TRANSACTION;
UPDATE
    "users"
SET
    "balance" = "balance" + 100
WHERE
    "username" = 'nicolas';
INSERT INTO
    "cash_movements" ("user_id", "type", "datetime" , "amount")
SELECT
    "id" AS "user_id",
    'deposit',
    CURRENT_TIMESTAMP,
    100
FROM
    "users"
WHERE
    "username" = 'nicolas';
COMMIT;

-- Withdraw 100 dollars
BEGIN TRANSACTION;
UPDATE
    "users"
SET
    "balance" = "balance" - 100
WHERE
    "username" = 'nicolas';
INSERT INTO
    "cash_movements" ("user_id", "type", "datetime" , "amount")
SELECT
    "id" AS "user_id",
    'withdrawal',
    CURRENT_TIMESTAMP,
    100
FROM
    "users"
WHERE
    "username" = 'nicolas';
COMMIT;

-- See the balance of a user
SELECT
    "username",
    "balance"
FROM
    "users"
WHERE
    "username" = 'nicolas';

-- See the current assets of a user
SELECT
    *
FROM
    "current_assets"
WHERE
    "username" = 'nicolas';

-- See history of transactions of a user
SELECT
    *
FROM
    "transactions_history"
WHERE
    "username" = 'nicolas';

-- See dividend history of a user
SELECT
    "dividends"."id",
    "username",
    "assets"."ticker",
    "amount_per_share",
    "datetime"
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
WHERE
    "username" = 'nicolas'
ORDER BY
    "datetime" DESC;

-- See latest market prices
SELECT
    *
FROM
    "latest_market_prices";

-- See unrealized profits of a user
SELECT
    *
FROM
    "unrealized_profits"
WHERE
    "username" = 'nicolas';

-- See realized profits of a user
SELECT
    *
FROM
    "realized_profits"
WHERE
    "username" = 'nicolas';

-- See dividends received of a user
SELECT
    *
FROM
    "dividends_received"
WHERE
    "username" = 'nicolas';

SELECT
    *
FROM
    "portfolio_overview"
WHERE
    "username" = 'nicolas';

-- See portfolio summary of a user
SELECT
    *
FROM
    "full_portfolio_summary"
WHERE
    "username" = 'nicolas';
