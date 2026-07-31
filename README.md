# Technical Approach & Architecture: Lender Incentive Engine

## 1. System Overview

The **Lender Incentive Engine** calculates operational and impact performance incentives for lending partners on the platform. The system operates on two execution streams:
1. **Real-time / Event-Driven Registration Stream:** Calculates potential maximum incentives (`Max_Potential_OI__c` and `Max_Potential_FLC__c`) upon loan origination/closing.
2. **Quarterly Batch Calculation Stream:** Aggregates performance data via `IncentiveQuarterlyBatch` to compute earned payouts (`Quarterly_OI_Earned__c` and `Quarterly_FLC_Earned__c`).

---

## 2. Data Model & Entity Relationships

The solution relies on standard Salesforce objects (`Account`, `Opportunity`) alongside custom configuration and transactional objects:
### Key Schema Elements
* **`Incentive__c`**: Stores computed maximum potential and quarterly earned amounts. Uses `Loan_Incentive_Key__c` (Text 255, Unique, External ID) to ensure deterministic upsert behavior without duplicate records.
* **`Lender_Exception__c`**: Overrides default rates and minimum loan thresholds per Account (Lender).
* **`Lender_Country_Multiplier__c` & `Lender_Value_Chain_Multiplier__c`**: Child records defining multiplicative scaling factors applied to base incentive rates.
* **`Monthly_Balance__c`**: Captures historical month-end principal balances evaluated during quarterly batch runs.

---

## 3. Calculation Architecture & Business Rules

Calculations are encapsulated in `IncentiveCalculator.cls` and supported by `LenderExceptionService.cls` and `LenderIncentiveConfig.cls`.

### 3.1 Eligibility & Gating Criteria
* **Minimum Loan Amount Threshold:** If the loan `Amount` is strictly less than `OI_Min_Loan_Amount__c` (defaulting to org baseline if no active exception exists), the calculated maximum potential incentive evaluates to `$0.00`.
* **Incentive Flags:** Calculation proceeds only when `Is_OI_Eligible__c` or `Is_FLC_Eligible__c` flags are set to `true`.

### 3.2 Rate Calculation Formulas

$$\text{Applied OI Rate} = \left( \text{Base OI Rate} + (\text{Impact Points} \times \text{Uplift Per Point}) \right) \times \prod \text{Multipliers}$$

$$\text{Applied FLC Rate} = \left( \text{Base FLC Rate} + \text{Returning Borrower Increment (if applicable)} \right) \times \prod \text{Multipliers}$$

Where:
* **Multipliers:** Product of matching `Lender_Country_Multiplier__c` (by `Country__c`) and `Lender_Value_Chain_Multiplier__c` (by `Value_Chain__c`).
* **Fallback Strategy:** If no custom `Lender_Exception__c` record is found for the given `AccountId`, `LenderIncentiveConfig.cls` supplies hardcoded baseline rates.

---

## 4. Execution Streams & Batch Processing

### Registration Stream (`IncentiveCalculator.calculateAndUpsertIncentives`)
* Accepts a list of Opportunity IDs.
* Queries related loan metadata (`Amount`, `Impact_Points__c`, `Country__c`, `Value_Chain__c`, `Is_Returning_Borrower__c`).
* Evaluates active lender exceptions and multipliers.
* Upserts `Incentive__c` records using `Loan_Incentive_Key__c`.

### Quarterly Batch Stream (`IncentiveQuarterlyBatch`)
* Implements `Database.Batchable<sObject>`.
* Queries active `Monthly_Balance__c` records for the target quarter.
* Aggregates month-end balances to determine average outstanding portfolio balances.
* Computes earned quarterly payouts (`Quarterly_OI_Earned__c` and `Quarterly_FLC_Earned__c`) and updates corresponding `Incentive__c` records.

---

## 5. Test Strategy & Validation

The test suite in `IncentiveCalculatorTest.cls` verifies end-to-end functionality under the following scenarios:

1. **Eligible Standard Loan:** Verifies correct applied rates, multiplier application, and positive incentive calculation.
2. **Below-Threshold Gating:** Ensures loans under `OI_Min_Loan_Amount__c` return `$0.00` earned/potential incentive.
3. **Fallback Configuration:** Confirms calculation stability when a Lender has no custom `Lender_Exception__c` configured.
4. **Batch Processing Execution:** Validates batch execution context against `Monthly_Balance__c` records.
Submission Checklist
