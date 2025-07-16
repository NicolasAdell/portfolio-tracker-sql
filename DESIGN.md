# Design Document

By Nicolas Fabian Adell

Video overview: [Portolio Tracker Database](https://www.youtube.com/watch?v=Nf53UhuFD7c)

# Portfolio Tracker Database

## Scope

The purpose of the database is to track and analyze the investment portfolio of multiple users. It has a structured way to store and query information and statistics. This includes asset purchases and sales, dividend payments, market prices over time, realized and unrealized profits, cash deposits and withdrawals, and portfolio performance, allocation and metrics. This database could be useful for several investment companies, banks, brokers, crypto exchanges and even for individual investors.

The scope of this database includes users, assets, transactions, dividends, market prices, cash movements and portfolio views. However, the scope of the database does not include financial advice, predictions, regulatory compliance (like taxes), automatic rebalancing, user security and authentication nor trading functionality.

## Functional Requirements

A user of this database should be able to evaluate their investment performance through views and queries with the following features:

- Register and manage basic user information
- Track investment transactions
- Record and view historical prices
- Track dividends received
- View realized profits
- Calculate unrealized profits or losses
- Track investment value and allocation
- View history of financial movements
- Access portfolio summary
- Prevent selling more assets than held

Outside the scope, the user should not be able to execute live trades or orders, access real market data, receive advice, financial forecasting, portfolio optimization, generate tax reports, or modify historical data.

## Representation

Entities are captured in SQLite tables with the following schema.

### Entities

The database is represented by the following six entities:

1. "users": It includes personal data of each user.
2. "Assets": It includes the assets held or used in transactions.
3. "transactions": It includes purchase and sell data of assets.
4. "dividends": It includes dividend payment data.
5. "market Prices": It includes market price data.
6. "cash Movements": It includes withdrawal and deposit data of money.

#### Users

- "id" (INTEGER, PRIMARY KEY): Unique identifier for each user (integer number), and primary key for users.

- "username" (TEXT, UNIQUE, NOT NULL): Login or display name, which is a text that cannot be NULL.

- "password" (TEXT, NOT NULL): Placeholder for authentication which should not be NULL.

- "names" (TEXT, NOT NULL): First name(s) of the user, which is a text that cannot be NULL.

- "surnames" (TEXT, NOT NULL): Last name(s) which is a text that cannot be NULL.

- "balance" (REAL, DEFAULT 0, CHECK ≥ 0): Available cash not yet invested. It is a real number which cannot be less than '0'.

#### Assets

- "id" (INTEGER, PRIMARY KEY): Unique ID for each asset, which is the primary key for assets as an integer.

- "type" (TEXT, NOT NULL): Type of asset (e.g. stock, crypto), which is a text that cannot be NULL.

- "name" (TEXT, UNIQUE, NOT NULL): Full asset name (e.g. “Apple Inc.”) which is a text that cannot be NULL.

- "ticker" (TEXT, UNIQUE, NOT NULL): Market symbol (e.g. “AAPL”) which is a text that cannot be NULL.

- "sector" (TEXT, NULLABLE): Optional grouping (e.g. “Technology”), which is a text.

#### Transactions

- "id" (INTEGER, PRIMARY KEY): Unique ID for each transaction, which is the primary key for transactions as an integer.

- "user_id" (INTEGER, FOREIGN KEY to users): Who performed the transaction. It is linked to the id of the user (integer).

- "asset_id" (INTEGER, FOREIGN KEY to assets): Which asset was traded. It is linked to the asset id of the user (integer).

- "datetime" (DATETIME, DEFAULT CURRENT_TIMESTAMP): When the trade occurred. It is a date and time with default as current date and time.

- "type" (TEXT, CHECK IN ('buy', 'sell')): Whether the asset was bought or sold, which is a text that can only be 'buy' or 'sell'.

- "quantity" (REAL, NOT NULL): Number of units of the asset, which is a real number (it could be a fraction) that cannot be NULL.

- "price" (REAL, NOT NULL, CHECK ≥ 0): Price per unit, which is a real number that should be greater than '0'.

#### Dividends

- "id" (INTEGER, PRIMARY KEY): Unique record per dividend event, which is a primary key as an integer.

- "user_id" (INTEGER, FOREIGN KEY to users): User receiving the dividend, which references the id of the user (integer).

- "asset_id" (INTEGER, FOREIGN KEY to assets): Asset that generated the dividend, which references the id of the asset (integer).

- "amount_per_share" (REAL, NOT NULL, CHECK ≥ 0): Dividend per unit held, which is a real number which cannot be NULL.

- "ex_date" (DATE, NOT NULL): Date of record for eligibility, which cannot be NULL.

- "datetime" (DATETIME, DEFAULT CURRENT_TIMESTAMP): Date and time when it was recorded, with current date and time as default.

#### Market Prices

- "asset_id" (INTEGER, FOREIGN KEY to assets): Asset being priced, which references the asset id (integer).

- "price" (REAL, NOT NULL, CHECK ≥ 0): Market value of the asset, which should be a real number greater than '0'.

- "datetime" (DATETIME, DEFAULT CURRENT_TIMESTAMP): Date and time of price record, with current ones as default.

The primary key is a composite of asset_id and datetime, ensuring that each price entry is unique.

#### Cash Movements

- "id" (INTEGER, PRIMARY KEY): Record of a deposit/withdrawal. It is a primary key to identify cash movements as an integer.

- "user_id" (INTEGER, FK to users): Who performed the operation, which references user id (integer).

- "type" (TEXT, CHECK IN ('deposit', 'withdrawal')): Nature of movement, which is a text that can only be 'deposit' or 'withdrawal'.

- "datetime" (DATETIME, DEFAULT CURRENT_TIMESTAMP): When the movement occurred, default is current date and time.

- "amount" (REAL, NOT NULL, CHECK ≥ 0): Value moved, which should be a positive real number.

### Relationships

The below entity relationship diagram describes the relationships among the entities in the database.

![ER Diagram](diagram.png)

The relationships are the following ones:

1. Users ↔ Transactions
Relationship: One-to-Many

Explanation: A single user can perform many transactions (buy/sell).
transactions.user_id → users.id

2. Users ↔ Dividends
Relationship: One-to-Many

Explanation: A user can receive multiple dividend payments across different assets.
dividends.user_id → users.id

3. Users ↔ Cash Movements
Relationship: One-to-Many

Explanation: A user can perform many deposits and withdrawals.
cash_movements.user_id → users.id

4. Assets ↔ Transactions
Relationship: One-to-Many

Explanation: Each asset can be involved in many buy/sell transactions by different users.
transactions.asset_id → assets.id

5. Assets ↔ Dividends
Relationship: One-to-Many

Explanation: Each asset can issue many dividends over time, which are then linked to specific users.
dividends.asset_id → assets.id

6. Assets ↔ Market Prices
Relationship: One-to-Many

Explanation: Each asset can have multiple market price entries over time, representing historical data.
market_prices.asset_id → assets.id

## Optimizations

### Indexes
Several indexes were created to accelerate frequent JOINs, filtering, and aggregation operations:

* "idx_users_username": Speeds up lookups by username.

* "idx_assets_tickers": Optimizes queries by ticker.

* "idx_transactions_user_id" and "idx_transactions_asset_id": Improve performance when querying a user’s or asset’s transactions.

* "idx_transactions_user_asset": Further improves performance when filtering by both user and asset.

* "idx_dividends_user_id" and "idx_dividends_asset_id": Help optimize dividend lookups by user and asset.

* "idx_market_prices_asset_id": Helps quickly retrieve all price history for a given asset.

### Views
Multiple views were created to encapsulate complex queries and expose summarized or user-friendly data for analytics and reporting:

* "current_assets": Calculates users’ current holdings with average cost basis.

* "latest_market_prices": Provides the latest price for each asset.

* "unrealized_profits": Estimates potential profits/losses from unsold assets.

* "realized_profits": Tracks profits from sold assets.

* "dividends_received": Computes dividends received per asset.

* "transactions_history": Aggregates cash movements, transactions, and dividends into one timeline.

* "portfolio_overview": Combines all data into a clear per-asset portfolio summary.

* "full_portfolio_summary": Gives a full picture of each user’s financial position.

## Triggers

* "check_quantity_before_selling": Prevents users from selling more of an asset than they currently hold.

* "prevent_edit_ticker": Disallows editing the ticker of an asset if it's already referenced in transactions, dividends, or market prices.

* "prevent_update_transactions": Blocks any update to existing transaction records.

* "prevent_delete_transactions": Prevents deletion of transaction records.

* "prevent_update_dividends": Disallows modifications to dividend records.

* "prevent_delete_dividends": Prevents deletion of dividend records.

* "prevent_update_market_prices": Prohibits updating past market prices.

* "prevent_delete_market_prices": Blocks deletion of historical market price entries.

* "prevent_update_cash_movements": Disallows any edits to recorded deposits or withdrawals.

* "prevent_delete_cash_movements": Prevents deletion of cash movement records.

## Limitations

The limitations of this database are:

- It does not support multi-currency transactions
- Each user has a single portfolio which cannot be shared
- It does not support dividends reinvestment nor taxation
- Views are static, so it is not possible to see the historic performance
- Not useful for trading since it does not have real-time data
- It has limited validations which could be a problem with incorrect data imported
- It does not support deletitions and modifications on "transactions", "dividends", "market_prices", "cash_movements" because it can cause data problems.
