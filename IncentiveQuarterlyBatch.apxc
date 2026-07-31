public class IncentiveQuarterlyBatch implements Database.Batchable<sObject> {

    public Database.QueryLocator start(Database.BatchableContext bc) {
        return Database.getQueryLocator([
            SELECT Id, Loan__c, Month_End_Balance__c, Loan__r.AccountId, Loan__r.Country__c, Loan__r.Value_Chain__c, Loan__r.Is_Returning_Borrower__c
            FROM Monthly_Balance__c
            WHERE Record_Date__c = THIS_QUARTER
        ]);
    }

    public void execute(Database.BatchableContext bc, List<Monthly_Balance__c> scope) {
        Set<Id> lenderIds = new Set<Id>();
        Map<Id, List<Monthly_Balance__c>> loanToBalances = new Map<Id, List<Monthly_Balance__c>>();

        for (Monthly_Balance__c mb : scope) {
            if (mb.Loan__r.AccountId != null) {
                lenderIds.add(mb.Loan__r.AccountId);
            }
            if (!loanToBalances.containsKey(mb.Loan__c)) {
                loanToBalances.put(mb.Loan__c, new List<Monthly_Balance__c>());
            }
            loanToBalances.get(mb.Loan__c).add(mb);
        }

        Map<Id, LenderIncentiveConfig> configMap = LenderExceptionService.getConfigsForLenders(lenderIds);
        List<Incentive__c> recordsToUpsert = new List<Incentive__c>();

        for (Id loanId : loanToBalances.keySet()) {
            List<Monthly_Balance__c> mbList = loanToBalances.get(loanId);
            Monthly_Balance__c sampleMB = mbList[0];
            LenderIncentiveConfig cfg = configMap.get(sampleMB.Loan__r.AccountId);
            if (cfg == null) cfg = new LenderIncentiveConfig(sampleMB.Loan__r.AccountId);

            Decimal avgBalance = 0.0;
            for (Monthly_Balance__c mb : mbList) {
                avgBalance += (mb.Month_End_Balance__c != null ? mb.Month_End_Balance__c : 0);
            }
            avgBalance = avgBalance / mbList.size();

            Decimal quarterlyOI = 0.0;
            Decimal quarterlyFLC = 0.0;

            if (cfg.isOIEligible && avgBalance >= cfg.oiMinLoan) {
                Decimal cMult = cfg.getCountryMultiplier(sampleMB.Loan__r.Country__c);
                Decimal vcMult = cfg.getValueChainMultiplier(sampleMB.Loan__r.Value_Chain__c);
                quarterlyOI = (avgBalance * cfg.oiBaseRate * cMult * vcMult) / 4.0;
            }

            if (cfg.isFLCEligible) {
                Decimal rate = cfg.flcBaseRate + (sampleMB.Loan__r.Is_Returning_Borrower__c == true ? cfg.flcReturningInc : 0);
                Decimal cMult = cfg.getCountryMultiplier(sampleMB.Loan__r.Country__c);
                Decimal vcMult = cfg.getValueChainMultiplier(sampleMB.Loan__r.Value_Chain__c);
                quarterlyFLC = (avgBalance * rate * cMult * vcMult) / 4.0;
            }

            Incentive__c inc = new Incentive__c();
            inc.Loan__c = loanId;
            inc.Loan_Incentive_Key__c = String.valueOf(loanId);
            inc.Quarterly_OI_Earned__c = quarterlyOI;
            inc.Quarterly_FLC_Earned__c = quarterlyFLC;

            recordsToUpsert.add(inc);
        }

        if (!recordsToUpsert.isEmpty()) {
            Database.upsert(recordsToUpsert, Incentive__c.Fields.Loan_Incentive_Key__c, false);
        }
    }

    public void finish(Database.BatchableContext bc) {}
}
