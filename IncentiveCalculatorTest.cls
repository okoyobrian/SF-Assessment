@isTest
private class IncentiveCalculatorTest {

    @testSetup
    static void setupTestData() {
        // 1. Create Test Lender (Account)
        Account lender = new Account(Name = 'Test Microfinance Bank');
        insert lender;

        // 2. Create Lender Exception (Active Overrides)
        Lender_Exception__c exc = new Lender_Exception__c(
            Lender__c = lender.Id,
            Is_Active__c = true,
            Is_OI_Eligible__c = true,
            Is_FLC_Eligible__c = true,
            OI_Min_Loan_Amount__c = 5000.00,
            OI_Revenue_Base_Rate__c = 0.0400, // 4%
            OI_Impact_Uplift_Per_Point__c = 0.0050, // 0.5% per point
            FLC_Base_Rate__c = 0.0800, // 8%
            FLC_Returning_Borrower_Increment__c = 0.0200 // 2%
        );
        insert exc;

        // 3. Create Multipliers
        Lender_Country_Multiplier__c countryMult = new Lender_Country_Multiplier__c(
            Lender_Exception__c = exc.Id,
            Country_Code__c = 'KEN',
            Multiplier__c = 1.10
        );
        insert countryMult;

        Lender_Value_Chain_Multiplier__c vcMult = new Lender_Value_Chain_Multiplier__c(
            Lender_Exception__c = exc.Id,
            Value_Chain__c = 'Coffee',
            Multiplier__c = 1.05
        );
        insert vcMult;

        // 4. Create Test Loans (Opportunities)
        List<Opportunity> testLoans = new List<Opportunity>();

        // Loan 1: Standard Eligible Loan
        testLoans.add(new Opportunity(
            Name = 'Eligible Coffee Loan',
            AccountId = lender.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = 20000.00,
            Impact_Points__c = 2,
            Country__c = 'KEN',
            Value_Chain__c = 'Coffee',
            Is_Returning_Borrower__c = true
        ));

        // Loan 2: Under Minimum Threshold Loan
        testLoans.add(new Opportunity(
            Name = 'Small Loan Below Min Threshold',
            AccountId = lender.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = 1000.00, // Below 5000 min threshold
            Impact_Points__c = 0,
            Country__c = 'KEN',
            Value_Chain__c = 'Coffee',
            Is_Returning_Borrower__c = false
        ));

        insert testLoans;

        // 5. Create Monthly Balances for Quarterly Batch Test
        List<Monthly_Balance__c> balances = new List<Monthly_Balance__c>();
        for (Opportunity loan : testLoans) {
            balances.add(new Monthly_Balance__c(
                Loan__c = loan.Id,
                Month_End_Balance__c = loan.Amount,
                Record_Date__c = Date.today()
            ));
        }
        insert balances;
    }

    @isTest
    static void testIncentiveCalculatorRegistrationStream() {
        List<Opportunity> loans = [SELECT Id FROM Opportunity];
        List<Id> loanIds = new List<Id>();
        for (Opportunity l : loans) {
            loanIds.add(l.Id);
        }

        Test.startTest();
        IncentiveCalculator.calculateAndUpsertIncentives(loanIds);
        Test.stopTest();

        // Verify Incentive records created via External ID upsert
        List<Incentive__c> incentives = [
            SELECT Id, Loan__c, Max_Potential_OI__c, Max_Potential_FLC__c, Calculation_Log__c 
            FROM Incentive__c
        ];
        
        System.assertEquals(2, incentives.size(), 'Should create/upsert exactly 2 incentive records.');

        Map<Id, Incentive__c> loanToIncentiveMap = new Map<Id, Incentive__c>();
        for (Incentive__c inc : incentives) {
            loanToIncentiveMap.put(inc.Loan__c, inc);
        }

        Opportunity eligibleLoan = [SELECT Id, Amount FROM Opportunity WHERE Name = 'Eligible Coffee Loan' LIMIT 1];
        Incentive__c eligibleIncentive = loanToIncentiveMap.get(eligibleLoan.Id);

        System.assertNotEquals(null, eligibleIncentive, 'Incentive record should exist for eligible loan.');
        System.assert(eligibleIncentive.Max_Potential_OI__c > 0, 'Max Potential OI should be greater than 0.');
        System.assert(eligibleIncentive.Max_Potential_FLC__c > 0, 'Max Potential FLC should be greater than 0.');

        Opportunity smallLoan = [SELECT Id FROM Opportunity WHERE Name = 'Small Loan Below Min Threshold' LIMIT 1];
        Incentive__c smallIncentive = loanToIncentiveMap.get(smallLoan.Id);

        System.assertEquals(0.00, smallIncentive.Max_Potential_OI__c, 'OI should be zero when loan amount is below threshold.');
    }

    @isTest
    static void testQuarterlyBatchExecution() {
        Test.startTest();
        IncentiveQuarterlyBatch batchJob = new IncentiveQuarterlyBatch();
        Database.executeBatch(batchJob);
        Test.stopTest();

        List<Incentive__c> incentives = [
            SELECT Id, Quarterly_OI_Earned__c, Quarterly_FLC_Earned__c 
            FROM Incentive__c
        ];

        System.assert(!incentives.isEmpty(), 'Quarterly batch should generate incentive records.');
    }

    @isTest
    static void testDefaultConfigFallback() {
        // Create Lender with NO Lender Exception
        Account defaultLender = new Account(Name = 'Default Fallback Lender');
        insert defaultLender;

        Opportunity fallbackLoan = new Opportunity(
            Name = 'Fallback Loan',
            AccountId = defaultLender.Id,
            StageName = 'Closed Won',
            CloseDate = Date.today(),
            Amount = 15000.00,
            Impact_Points__c = 1,
            Country__c = 'UGA',
            Value_Chain__c = 'Maize',
            Is_Returning_Borrower__c = false
        );
        insert fallbackLoan;

        Test.startTest();
        IncentiveCalculator.calculateAndUpsertIncentives(new List<Id>{ fallbackLoan.Id });
        Test.stopTest();

        Incentive__c inc = [SELECT Id, Max_Potential_OI__c, Max_Potential_FLC__c FROM Incentive__c WHERE Loan__c = :fallbackLoan.Id LIMIT 1];
        System.assertNotEquals(null, inc, 'Incentive record should be created using org defaults.');
        System.assert(inc.Max_Potential_OI__c > 0, 'OI should be calculated using system default base rate.');
    }
}
