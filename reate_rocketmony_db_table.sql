/* This script creates a database named 'finances' and sets up tables, views, and queries for managing and analyzing financial transactions.
-- It includes the following steps:
-- Create the 'finances' database with a specific collation.
-- Use the 'finances' database.

-- Drop the 'rocketmoney_transactions' table if it exists.
-- Create the 'rocketmoney_transactions' table with various columns to store transaction details.
-- Create or alter a view 'rocketmoney_transactions_view' to provide a structured view of transactions with additional calculated fields for debit and credit.
-- Create or alter a view 'monthly_income_expenses' to summarize monthly income and expenses.
-- Create or alter a view 'credit_card_summary' to summarize credit card transactions by institution, account, year, and month.
-- Declare variables and set values to get the current month's credit card summary or an offset month summary.
-- Select and display the credit card summary for the specified month and year.


PRE-REQUISITES:
-- Install SQL Server Express 2022: https://learn.microsoft.com/en-us/sql/database-engine/configure-windows/sql-server-express-localdb?view=sql-server-ver16
-- In CMD (not pwsh):

REM Create an instance of LocalDB
"C:\Program Files\Microsoft SQL Server\160\Tools\Binn\SqlLocalDB.exe" create finances
REM Start the instance of LocalDB
"C:\Program Files\Microsoft SQL Server\160\Tools\Binn\SqlLocalDB.exe" start finances

*/

-- Create the 'finances' database with a specific collation
CREATE DATABASE [finances] COLLATE Latin1_general_100_bin2;

-- Use the 'finances' database
USE [finances];

-- Drop the 'rocketmoney_transactions' table if it exists
DROP TABLE IF EXISTS [rocketmoney_transactions];
GO

-- Create the 'rocketmoney_transactions' table with various columns to store transaction details
CREATE TABLE [rocketmoney_transactions] (
    [date] DATE NOT NULL, -- Transaction date
    [original_date] DATE NOT NULL, -- Original transaction date
    [account_type] VARCHAR(255) NOT NULL, -- Type of account (e.g., Credit Card, Bank Account)
    [account_name] VARCHAR(255) NOT NULL, -- Name of the account
    [account_number] VARCHAR(255) NOT NULL, -- Account number
    [institution_name] VARCHAR(255) NOT NULL, -- Name of the financial institution
    [name] VARCHAR(255) NOT NULL, -- Name of the transaction
    [custom_name] VARCHAR(255) NOT NULL, -- Custom name for the transaction
    [amount] DECIMAL(10,2) NOT NULL, -- Transaction amount
    [description] TEXT NOT NULL, -- Description of the transaction
    [category] VARCHAR(255) NOT NULL, -- Category of the transaction (e.g., Income, Expense)
    [note] TEXT NOT NULL, -- Additional notes for the transaction
    [ignored_from] VARCHAR(255) NOT NULL, -- Ignored from specific reports
    [tax_deductible] VARCHAR(255) NOT NULL -- Indicates if the transaction is tax-deductible
);
GO

-- Create or alter a view 'rocketmoney_transactions_view' to provide a structured view of transactions with additional calculated fields for debit and credit
CREATE OR ALTER VIEW rocketmoney_transactions_view AS
SELECT 
    date,
    original_date,
    account_type,
    account_name,
    account_number,
    institution_name,
    name,
    custom_name,
    amount,
    description,
    category,
    note,
    ignored_from,
    tax_deductible,
    CASE 
        WHEN amount > 0 THEN amount -- Calculate debit amount
        ELSE 0 
    END AS debit,
    CASE 
        WHEN amount < 0 THEN -amount -- Calculate credit amount
        ELSE 0 
    END AS credit
FROM 
    rocketmoney_transactions;
GO

-- Create or alter a view 'monthly_income_expenses' to summarize monthly income and expenses
CREATE OR ALTER VIEW [dbo].[monthly_income_expenses] AS
WITH MonthlyTransactions AS (
    SELECT 
        DATEFROMPARTS(YEAR([date]), MONTH([date]), 1) as month_start, -- Get the start of the month
        CASE 
            WHEN category = 'Income' THEN ABS(amount) -- Calculate income
            ELSE 0
        END as income,
        CASE 
            WHEN category != 'Income' THEN amount -- Calculate expense
            ELSE 0
        END as expense
    FROM [dbo].[rocketmoney_transactions_view]
)
SELECT 
    month_start,
    SUM(income) as total_income, -- Sum of income for the month
    SUM(expense) as total_expense, -- Sum of expenses for the month
    SUM(income) - SUM(expense) as difference -- Difference between income and expenses
FROM MonthlyTransactions
GROUP BY month_start; -- Group by month start date
GO

-- Create or alter a view 'credit_card_summary' to summarize credit card transactions by institution, account, year, and month
CREATE OR ALTER VIEW credit_card_summary AS
WITH LastPaymentDate AS (
    SELECT 
        account_number,
        MAX(date) AS last_payment_date
    FROM 
        rocketmoney_transactions_view
    WHERE 
        amount < 0 
        AND account_type = 'Credit Card'
    GROUP BY 
        account_number
)
SELECT 
    rv.institution_name, -- Name of the financial institution
    rv.account_name, -- Name of the account
    rv.account_number, -- Account number
    DATEPART(YEAR, rv.date) AS year, -- Year of the transaction
    DATEPART(MONTH, rv.date) AS month, -- Month of the transaction
    SUM(rv.debit) AS total_spent, -- Total amount spent
    SUM(rv.credit) AS total_paid, -- Total amount paid
    SUM(rv.debit) - SUM(rv.credit) AS difference, -- Difference between spent and paid amounts
    SUM(CASE 
        WHEN rv.date > lp.last_payment_date 
        THEN rv.debit - rv.credit 
        ELSE 0 
    END) AS difference_since_last_payment -- Difference since last payment
                                          -- ! Important: Transactions can occur on the same date.
                                          -- Meaning that this column may not reflect transactions that occur later in the day.
FROM 
    rocketmoney_transactions_view rv
LEFT JOIN 
    LastPaymentDate lp ON rv.account_number = lp.account_number
WHERE 
    rv.account_type = 'Credit Card' -- Filter for credit card transactions
GROUP BY 
    rv.institution_name,
    rv.account_name,
    rv.account_number,
    DATEPART(YEAR, rv.date),
    DATEPART(MONTH, rv.date),
    lp.last_payment_date; -- Group by institution, account, year, month, and last payment date
GO

/* --- Actual Query --- */  

-- Declare variables and set values to get the current month's credit card summary or an offset month summary
DECLARE @year INT
DECLARE @month INT
DECLARE @months_offset INT
SET @months_offset = 0 -- Set the offset for months (0 for current month)
SET @year = DATEPART(YEAR, DATEADD(MONTH, -@months_offset, GETDATE())) -- Calculate the year based on the offset
SET @month = DATEPART(MONTH, DATEADD(MONTH, -@months_offset, GETDATE())) -- Calculate the month based on the offset

-- Select and display the credit card summary for the specified month and year
SELECT * FROM credit_card_summary 
WHERE  1=1
AND [year] = @year -- Filter by year
AND [month] = @month; -- Filter by month
GO
