public class IncentiveCalculator {

    public static void calculateAndUpsertIncentives(List<Id> loanIds) {
        if (loanIds == null || loanIds.isEmpty()) return;

        List<Opportunity> loans = [
            SELECT Id, AccountId, Amount, Impact_Points__c, Country__c, Value_Chain__c, Is_Returning_Borrower__c
            FROM Opportunity
            WHERE Id IN :loanIds
        ];

        Set<Id> lenderIds = new Set<Id>();
        for (Opportunity l : loans) {
            if (l.AccountId != null) lenderIds.add(l.AccountId);
        }

        Map<Id, LenderIncentiveConfig> configMap = LenderExceptionService.getConfigsForLenders(lenderIds);
        List<Incentive__c> recordsToUpsert = new List<Incentive__c>();

        for (Opportunity loan : loans) {
            LenderIncentiveConfig cfg = configMap.get(loan.AccountId);
            if (cfg == null) cfg = new LenderIncentiveConfig(loan.AccountId);

            Decimal maxOI = 0.0;
            Decimal maxFLC = 0.0;
            List<String> logs = new List<String>();

            // 1. Enforce OI Eligibility & Rules
            if (!cfg.isOIEligible) {
                logs.add('OI Gated: Lender ineligible for OI.');
            } else if (loan.Amount == null || loan.Amount < cfg.oiMinLoan) {
                logs.add('OI Threshold Failed: Loan amount (' + loan.Amount + ') < Min (' + cfg.oiMinLoan + ').');
            } else {
                Decimal baseRate = cfg.oiBaseRate;
                Decimal points = loan.Impact_Points__c != null ? loan.Impact_Points__c : 0;
                Decimal uplift = points * cfg.oiImpactUplift;
                Decimal cMult = cfg.getCountryMultiplier(loan.Country__c);
                Decimal vcMult = cfg.getValueChainMultiplier(loan.Value_Chain__c);

                Decimal effectiveRate = (baseRate + uplift) * cMult * vcMult;
                maxOI = loan.Amount * effectiveRate;
                logs.add('OI Calculated: Amount(' + loan.Amount + ') * Rate(' + effectiveRate + ') = ' + maxOI);
            }

            // 2. Enforce FLC Eligibility & Rules
            if (!cfg.isFLCEligible) {
                logs.add('FLC Gated: Lender ineligible for FLC.');
            } else {
                Decimal baseRate = cfg.flcBaseRate;
                if (loan.Is_Returning_Borrower__c == true) {
                    baseRate += cfg.flcReturningInc;
                }
                Decimal cMult = cfg.getCountryMultiplier(loan.Country__c);
                Decimal vcMult = cfg.getValueChainMultiplier(loan.Value_Chain__c);

                Decimal effectiveRate = baseRate * cMult * vcMult;
                maxFLC = (loan.Amount != null ? loan.Amount : 0) * effectiveRate;
                logs.add('FLC Calculated: Amount(' + loan.Amount + ') * Rate(' + effectiveRate + ') = ' + maxFLC);
            }

            // 3. Construct Record with Snapshot & Audit Logging
            Incentive__c inc = new Incentive__c();
            inc.Loan__c = loan.Id;
            inc.Loan_Incentive_Key__c = String.valueOf(loan.Id); // External ID for atomic upsert
            inc.Max_Potential_OI__c = maxOI;
            inc.Max_Potential_FLC__c = maxFLC;
            inc.Applied_OI_Rate__c = cfg.oiBaseRate;
            inc.Applied_FLC_Rate__c = cfg.flcBaseRate;
            inc.Applied_Multipliers__c = 'Country: ' + cfg.getCountryMultiplier(loan.Country__c) + 'x | VC: ' + cfg.getValueChainMultiplier(loan.Value_Chain__c) + 'x';
            inc.Calculation_Log__c = String.join(logs, ' | ');

            recordsToUpsert.add(inc);
        }

        if (!recordsToUpsert.isEmpty()) {
            Database.upsert(recordsToUpsert, Incentive__c.Fields.Loan_Incentive_Key__c, false);
        }
    }
}
